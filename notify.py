import os
import random
import string
import sys

import requests


def get_status_info(status):
    status = status.lower()
    if status == "start":
        return "[START]", "START BUILD", "Creating the environment..."
    if status == "sync":
        return "[SYNC]", "SYNCHRONIZING", "Loading source code..."
    if status == "build":
        return "[BUILD]", "BUILDING", "ROM build in progress..."
    if status == "upload":
        return "[UPLOAD]", "UPLOADING", "Uploading ROM..."
    if status == "success":
        return "[OK]", "SUCCESS", "The process is complete."
    if status == "fail":
        return "[FAIL]", "FAILURE", "An error has occurred."
    return "[INFO]", "UPDATE STATUS", status


def read_optional_file(path):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as file:
            return file.read().strip()
    return ""


def send_telegram_message(bot_token, chat_id, message, msg_id=None):
    if msg_id:
        url = f"https://api.telegram.org/bot{bot_token}/editMessageText"
        payload = {
            "chat_id": chat_id,
            "message_id": msg_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True,
        }
    else:
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True,
        }

    response = requests.post(url, json=payload)
    response.raise_for_status()
    return response.json()


def build_public_message(status, repo_name, build_id, builder_name=""):
    icon, status_title, status_desc = get_status_info(status)
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    action_url = f"https://github.com/{repo_name}/actions/runs/{run_id}" if run_id else f"https://github.com/{repo_name}/actions"

    codename = read_optional_file("bin/ddevice/device_code.txt") or read_optional_file("bin/ddevice/device_model.txt") or "Determining..."
    version_rom = read_optional_file("bin/ddevice/base_rom_code.txt") or read_optional_file("bin/ddevice/base_build_id.txt") or "Determining..."
    version_tool = read_optional_file("Version") or "Determining..."

    builder_text = f"*Builder:* {builder_name}\n" if builder_name else ""

    return (
        f"{icon} *{status_title}*\n"
        f"{builder_text}"
        f"*Device:* `{codename}`\n"
        f"*Base ROM:* `{version_rom}`\n"
        f"*Tool Version:* `{version_tool}`\n"
        f"*Status:* _{status_desc}_\n"
        f"*Build ID:* `{build_id}`\n"
        f"*Workflow:* [Open run]({action_url})"
    )


def build_private_message(status, public_message, drive_link):
    lines = [public_message, ""]

    if status.lower() == "success":
        lines.append("DeadZone Lite build completed successfully. The file has been uploaded.")
    elif status.lower() == "fail":
        lines.append("DeadZone Lite build failed. Check the workflow log for the error details.")

    if drive_link:
        lines.append(f"Drive link: {drive_link}")

    return "\n".join(lines)


def send_notification(status, repo_name, release_chat_id, bot_token, private_chat_id=None, msg_id=None, build_id="Unknown", builder_name="", builder_id=""):
    public_message = build_public_message(status, repo_name, build_id, builder_name)
    drive_link = read_optional_file("bin/ddevice/drive_link.txt")

    try:
        response_data = send_telegram_message(bot_token, release_chat_id, public_message, msg_id)
        new_msg_id = response_data.get("result", {}).get("message_id")

        if not msg_id and new_msg_id and "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as file:
                file.write(f"TELEGRAM_MSG_ID={new_msg_id}\n")
            print(f"Saved TELEGRAM_MSG_ID={new_msg_id} to GITHUB_ENV.")

        print("Notification sent/updated to the release chat successfully.")

        if status.lower() in ["success", "fail"] and private_chat_id:
            private_message = build_private_message(status, public_message, drive_link)
            try:
                send_telegram_message(bot_token, private_chat_id, private_message)
                print(f"Private notification sent successfully to {private_chat_id}")
            except Exception as error:
                print(f"Private message sending error: {error}")

    except Exception as error:
        print(f"Error occurred while sending notification: {error}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python notify.py <status> <repo_name> <rom_link> [prefix_id] [builder_name] [builder_id]")
        sys.exit(1)

    status = sys.argv[1]
    repo_name = sys.argv[2]
    prefix = sys.argv[4] if len(sys.argv) > 4 else "build"
    builder_name = sys.argv[5] if len(sys.argv) > 5 else ""
    builder_id = sys.argv[6] if len(sys.argv) > 6 else ""

    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    release_chat_id = os.environ.get("TELEGRAM_RELEASE_GROUP_ID") or os.environ.get("TELEGRAM_CHANNEL_ID")
    private_chat_id = os.environ.get("MEZO_PRIVATE_CHAT_ID")
    msg_id = os.environ.get("TELEGRAM_MSG_ID")
    build_id = os.environ.get("TELEGRAM_BUILD_ID")

    if not build_id:
        random_digits = "".join(random.choices(string.digits, k=8))
        build_id = f"{prefix}_{random_digits}"
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as file:
                file.write(f"TELEGRAM_BUILD_ID={build_id}\n")

    if not bot_token or not release_chat_id:
        print("Error: Missing TELEGRAM_BOT_TOKEN or TELEGRAM_RELEASE_GROUP_ID (TELEGRAM_CHANNEL_ID is fallback only).")
        sys.exit(1)

    send_notification(
        status,
        repo_name,
        release_chat_id,
        bot_token,
        private_chat_id=private_chat_id,
        msg_id=msg_id,
        build_id=build_id,
        builder_name=builder_name,
        builder_id=builder_id,
    )
