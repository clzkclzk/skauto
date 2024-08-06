import curses

def server_selection(stdscr):
    curses.curs_set(0)
    height, width = stdscr.getmaxyx()
    selected_server = None
    servers = []

    with open('serverlist.cfg', 'r') as file:
        servers = [line.strip() for line in file.readlines()]

    current_row = 0
    selected_row = -1

    def print_menu(stdscr, selected_row):
        stdscr.clear()
        stdscr.addstr(0, (width // 2) - (len("서버 선택") // 2), "서버 선택", curses.A_BOLD)
        for idx, server in enumerate(servers):
            x_position = (width // 2) - (len(server) // 2)
            checkbox = "[x]" if idx == selected_row else "[ ]"
            if idx == current_row:
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(height // 4 + idx, x_position - 4, f"{checkbox} {server}")
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(height // 4 + idx, x_position - 4, f"{checkbox} {server}")

        select_x = (width // 2) - 10
        cancel_x = (width // 2) + 10
        if current_row == len(servers):
            stdscr.attron(curses.color_pair(1))
            stdscr.addstr(height - 2, select_x, "선택", curses.A_REVERSE)
            stdscr.attroff(curses.color_pair(1))
        else:
            stdscr.addstr(height - 2, select_x, "선택")

        if current_row == len(servers) + 1:
            stdscr.attron(curses.color_pair(1))
            stdscr.addstr(height - 2, cancel_x, "취소", curses.A_REVERSE)
            stdscr.attroff(curses.color_pair(1))
        else:
            stdscr.addstr(height - 2, cancel_x, "취소")

        stdscr.refresh()

    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

    while True:
        print_menu(stdscr, selected_row)
        key = stdscr.getch()

        if key == curses.KEY_UP and current_row > 0:
            current_row -= 1
        elif key == curses.KEY_DOWN and current_row < len(servers) + 1:
            current_row += 1
        elif key == curses.KEY_LEFT or key == curses.KEY_RIGHT:
            pass
        elif key == curses.KEY_ENTER or key in [10, 13]:
            if current_row == len(servers):
                if selected_row != -1:
                    selected_server = servers[selected_row]
                break
            elif current_row == len(servers) + 1:
                break
            else:
                if selected_row == current_row:
                    selected_row = -1
                else:
                    selected_row = current_row
        elif key == 27:
            break

    return selected_server