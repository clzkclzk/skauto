import os
import curses
from datetime import datetime

def update_progress(stdscr, progress, message):
    height, width = stdscr.getmaxyx()
    progress_bar_length = width - 20
    filled_length = int(progress_bar_length * progress // 100)
    progress_bar = '#' * filled_length + '-' * (progress_bar_length - filled_length)
    stdscr.addstr(height - 2, 10, f"[{progress_bar}] {progress}%".ljust(width - 20), curses.color_pair(2))
    stdscr.addstr(height - 1, 10, " " * (width - 20), curses.color_pair(2))  # Clear previous message
    stdscr.addstr(height - 1, 10, message, curses.color_pair(2))
    stdscr.refresh()

def execute_diagnostic(stdscr, selected_server):
    stdscr.clear()
    stdscr.addstr(0, 0, "진단을 시작합니다...", curses.color_pair(2))
    stdscr.refresh()

    server_details = selected_server.split(';')
    if len(server_details) < 5:
        stdscr.addstr(1, 0, "서버 정보가 올바르지 않습니다.", curses.color_pair(2))
        stdscr.refresh()
        stdscr.getch()
        return

    server_ip = server_details[3].strip()
    server_id = server_details[4].strip()
    server_os = server_details[0].strip()
    server_middle = server_details[1].strip()

    if not server_ip or not server_id:
        stdscr.addstr(1, 0, "서버 IP 또는 ID가 올바르지 않습니다.", curses.color_pair(2))
        stdscr.addstr(2, 0, f"server_ip: '{server_ip}', server_id: '{server_id}'", curses.color_pair(2))
        stdscr.refresh()
        stdscr.getch()
        return

    # Prompt user for password
    stdscr.addstr(3, 0, "비밀번호를 입력하세요: ", curses.color_pair(2))
    curses.echo()
    password = stdscr.getstr(3, 20, 100).decode('utf-8')
    curses.noecho()

    # Convert Windows path to WSL path
    local_script_path = "/mnt/d/code/apa_test.sh"  # Adjust path for WSL

    # Generate file name based on current date and ensure it is unique
    current_time = datetime.now().strftime('%y%m%d')
    base_path = f"/mnt/d/code/{server_ip}_{server_os}_{server_middle}_{current_time}"
    file_index = 1
    processed_result_path = f"{base_path}_{file_index}.txt"
    while os.path.exists(processed_result_path):
        file_index += 1
        processed_result_path = f"{base_path}_{file_index}.txt"

    update_progress(stdscr, 0, "진단을 준비 중...")

    # Upload the script to the remote server
    upload_command = f"sshpass -p '{password}' scp {local_script_path} {server_id}@{server_ip}:/tmp/apa_test.sh"
    os.system(upload_command)

    update_progress(stdscr, 20, "스크립트를 원격 서버에 업로드 중...")

    # Ensure the script has execution permissions
    permission_command = f"sshpass -p '{password}' ssh {server_id}@{server_ip} 'chmod +x /tmp/apa_test.sh'"
    os.system(permission_command)

    update_progress(stdscr, 40, "스크립트 실행 권한 설정 중...")

    # Execute the script on the remote server and save the output to a temporary file
    execute_command = f"sshpass -p '{password}' ssh {server_id}@{server_ip} 'bash /tmp/apa_test.sh > /tmp/diagnostic_result.txt'"
    os.system(execute_command)

    update_progress(stdscr, 60, "스크립트 실행 중...")

    # Download the result file
    temp_result_path = "/tmp/diagnostic_result.txt"
    download_command = f"sshpass -p '{password}' scp {server_id}@{server_ip}:{temp_result_path} {processed_result_path}"
    os.system(download_command)

    update_progress(stdscr, 80, "결과 파일 다운로드 중...")

    # Check if the file was downloaded successfully
    if not os.path.exists(processed_result_path):
        stdscr.addstr(8, 0, f"결과 파일을 찾을 수 없습니다: {processed_result_path}", curses.color_pair(2))
        stdscr.refresh()
        stdscr.getch()
        return

    update_progress(stdscr, 100, "진단이 완료되었습니다. 결과 파일이 저장되었습니다.")
    stdscr.getch()
