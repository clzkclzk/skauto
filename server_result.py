import curses
import os

def display_file_contents(stdscr, file_path):
    stdscr.clear()
    height, width = stdscr.getmaxyx()
    with open(file_path, 'r') as file:
        lines = file.readlines()

    current_line = 0
    while True:
        stdscr.clear()
        for i in range(height - 1):  # Leave one line for instructions or prompt
            if current_line + i < len(lines):
                line = lines[current_line + i].strip()
                stdscr.addstr(i, 0, line[:width])
        stdscr.addstr(height - 1, 0, "Use UP/DOWN arrows to scroll, Press ESC to go back.")
        stdscr.refresh()

        key = stdscr.getch()
        if key == curses.KEY_UP and current_line > 0:
            current_line -= 1
        elif key == curses.KEY_DOWN and current_line + height - 1 < len(lines):
            current_line += 1
        elif key == 27:  # ESC key
            break

def view_diagnostic_results(stdscr):
    curses.curs_set(0)
    height, width = stdscr.getmaxyx()
    txt_files = [f for f in os.listdir('/mnt/d/code') if f.endswith('.txt')]
    current_row = 0
    selected_row = -1

    def print_menu(stdscr, selected_row):
        stdscr.clear()
        stdscr.addstr(0, (width // 2) - (len("진단 결과 보기") // 2), "진단 결과 보기", curses.A_BOLD)
        for idx, file in enumerate(txt_files):
            x_position = (width // 2) - (len(file) // 2)
            checkbox = "[x]" if idx == selected_row else "[ ]"
            if idx == current_row:
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(height // 4 + idx, x_position - 4, f"{checkbox} {file}")
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(height // 4 + idx, x_position - 4, f"{checkbox} {file}")

        select_x = (width // 2) - 10
        cancel_x = (width // 2) + 10
        if current_row == len(txt_files):
            stdscr.attron(curses.color_pair(1))
            stdscr.addstr(height - 2, select_x, "선택", curses.A_REVERSE)
            stdscr.attroff(curses.color_pair(1))
        else:
            stdscr.addstr(height - 2, select_x, "선택")

        if current_row == len(txt_files) + 1:
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
        elif key == curses.KEY_DOWN and current_row < len(txt_files) + 1:
            current_row += 1
        elif key == curses.KEY_LEFT or key == curses.KEY_RIGHT:
            pass
        elif key == curses.KEY_ENTER or key in [10, 13]:
            if current_row == len(txt_files):
                if selected_row != -1:
                    selected_file = os.path.join('/mnt/d/code', txt_files[selected_row])
                    display_file_contents(stdscr, selected_file)
                break
            elif current_row == len(txt_files) + 1:
                break
            else:
                if selected_row == current_row:
                    selected_row = -1
                else:
                    selected_row = current_row
        elif key == 27:
            break

    return

# Ensure the function is only defined and not executed on import
if __name__ == '__main__':
    curses.wrapper(view_diagnostic_results)