import curses
from curses import wrapper
import pyfiglet
import unicodedata
from server_registration import server_registration
from server_deletion import server_deletion
from server_diag import execute_diagnostic
from server_select import server_selection
from server_result import view_diagnostic_results

def get_display_length(text):
    length = 0
    for char in text:
        if unicodedata.east_asian_width(char) in ('F', 'W'):
            length += 2
        else:
            length += 1
    return length

def main_menu(stdscr):
    figlet = pyfiglet.Figlet(font='slant')
    hello_msg = figlet.renderText('O  -  REGION')
    hello_lines = hello_msg.split('\n')

    height, width = stdscr.getmaxyx()
    selected_server = None

    def display_centered_text(stdscr, lines):
        stdscr.clear()
        for i, line in enumerate(lines):
            if line.strip():
                stdscr.addstr(height // 4 + i, (width // 2) - (get_display_length(line) // 2), line, curses.color_pair(2))

    menu = ['서버 등록', '서버 삭제', '서버 선택', '진단 수행', '진단 결과 보기']

    def print_menu(stdscr, selected_row_idx):
        stdscr.clear()
        for i, line in enumerate(hello_lines):
            if line.strip():
                stdscr.addstr(height // 4 + i, (width // 2) - (get_display_length(line) // 2), line, curses.color_pair(2))

        if selected_server:
            stdscr.addstr(height // 4 + len(hello_lines) + 1, (width // 2) - (get_display_length(selected_server) // 2), f"Selected Server: {selected_server}", curses.color_pair(2))

        total_length = sum(get_display_length(item) for item in menu) + 3 * (len(menu) - 1)
        start_x = (width - total_length) // 2
        menu_y = height // 2 + len(hello_lines) // 2

        current_x = start_x
        for idx, item in enumerate(menu):
            if idx == selected_row_idx:
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(menu_y, current_x, item)
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(menu_y, current_x, item)
            current_x += get_display_length(item) + 3

        stdscr.refresh()

    curses.start_color()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLACK)
    #curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
    #curses.init_pair(2, curses.COLOR_RED, curses.COLOR_GREEN)

    stdscr.keypad(True)

    selected_row_idx = 0
    print_menu(stdscr, selected_row_idx)

    while True:
        key = stdscr.getch()

        if key == curses.KEY_LEFT and selected_row_idx > 0:
            selected_row_idx -= 1
        elif key == curses.KEY_RIGHT and selected_row_idx < len(menu) - 1:
            selected_row_idx += 1
        elif key == curses.KEY_ENTER or key in [10, 13]:
            stdscr.clear()
            stdscr.refresh()
            if selected_row_idx == 0:
                server_registration(stdscr)
            elif selected_row_idx == 1:
                server_deletion(stdscr)
            elif selected_row_idx == 2:
                selected_server = server_selection(stdscr)
            elif selected_row_idx == 3:
                execute_diagnostic(stdscr, selected_server)
            elif selected_row_idx == 4:
                view_diagnostic_results(stdscr)
            print_menu(stdscr, selected_row_idx)
        elif key == 27:
            break

        print_menu(stdscr, selected_row_idx)

if __name__ == '__main__':
    wrapper(main_menu)
