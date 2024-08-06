import curses

def server_deletion(stdscr):
    try:
        with open('serverlist.cfg', 'r') as file:
            servers = [line.strip() for line in file.readlines()]
    except FileNotFoundError:
        servers = []

    selected_servers = [False] * len(servers)
    current_idx = 0
    submenu_height, submenu_width = len(servers) + 6, 50  # Adjusted height for better visual
    start_y = (curses.LINES - submenu_height) // 2
    start_x = (curses.COLS - submenu_width) // 2

    win = curses.newwin(submenu_height, submenu_width, start_y, start_x)
    win.keypad(True)

    while True:
        win.clear()
        win.box()

        for idx, server in enumerate(servers):
            if idx == current_idx:
                win.attron(curses.color_pair(1))
            checkbox = "[X]" if selected_servers[idx] else "[ ]"
            win.addstr(1 + idx, 2, f"{checkbox} {server}")
            if idx == current_idx:
                win.attroff(curses.color_pair(1))

        # Display Delete and Cancel buttons
        if len(servers) > 0:
            if current_idx == len(servers):
                win.attron(curses.color_pair(1))
            win.addstr(submenu_height - 2, submenu_width // 4 - 6, " 삭제 ")
            if current_idx == len(servers):
                win.attroff(curses.color_pair(1))

            if current_idx == len(servers) + 1:
                win.attron(curses.color_pair(1))
            win.addstr(submenu_height - 2, 3 * submenu_width // 4 - 6, " 취소 ")
            if current_idx == len(servers) + 1:
                win.attroff(curses.color_pair(1))

        win.refresh()

        key = win.getch()
        if key == curses.KEY_UP and current_idx > 0:
            current_idx -= 1
        elif key == curses.KEY_DOWN and current_idx < len(servers) + 1:
            current_idx += 1
        elif key == curses.KEY_ENTER or key in [10, 13]:
            if current_idx < len(servers):
                selected_servers[current_idx] = not selected_servers[current_idx]
            elif current_idx == len(servers):  # 삭제 버튼
                servers_to_delete = [servers[i] for i, selected in enumerate(selected_servers) if selected]
                if servers_to_delete:
                    with open('serverlist.cfg', 'w') as file:
                        file.writelines(f"{server}\n" for server in servers if server not in servers_to_delete)
                    stdscr.clear()
                    stdscr.addstr(curses.LINES - 2, 0, "서버가 삭제되었습니다. 계속하려면 아무 키나 누르세요.")
                    stdscr.refresh()
                    stdscr.getch()
                break
            elif current_idx == len(servers) + 1:  # 취소 버튼
                break
        elif key == 27:  # ESC 키로 종료
            break