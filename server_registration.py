import curses

def server_registration(stdscr):
    def print_sub_menu(stdscr, title, options, selected_idx, checked_idx):
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        # Calculate starting y position for centered alignment
        start_y = (height - (len(options) + 3)) // 2
        
        stdscr.addstr(start_y, (width // 2) - (len(title) // 2), title, curses.color_pair(2))
        
        for idx, option in enumerate(options):
            checkbox = "[X]" if idx == checked_idx else "[ ]"
            option_str = f"{checkbox} {option}"
            if idx == selected_idx:
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(start_y + 2 + idx, (width // 2) - (len(option_str) // 2), option_str)
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(start_y + 2 + idx, (width // 2) - (len(option_str) // 2), option_str)
        
        select_str = '[선택]'
        cancel_str = '[취소]'
        if selected_idx == len(options):
            stdscr.attron(curses.color_pair(1))
            stdscr.addstr(start_y + 2 + len(options), (width // 2) - 10, select_str)
            stdscr.attroff(curses.color_pair(1))
        else:
            stdscr.addstr(start_y + 2 + len(options), (width // 2) - 10, select_str)
        
        if selected_idx == len(options) + 1:
            stdscr.attron(curses.color_pair(1))
            stdscr.addstr(start_y + 2 + len(options), (width // 2) + 4, cancel_str)
            stdscr.attroff(curses.color_pair(1))
        else:
            stdscr.addstr(start_y + 2 + len(options), (width // 2) + 4, cancel_str)

        stdscr.refresh()

    def selection_screen(stdscr, title, options):
        selected_idx = 0
        checked_idx = -1
        while True:
            print_sub_menu(stdscr, title, options, selected_idx, checked_idx)
            key = stdscr.getch()

            if key == curses.KEY_UP and selected_idx > 0:
                selected_idx -= 1
            elif key == curses.KEY_DOWN and selected_idx < len(options) + 2:
                selected_idx += 1
            elif key == curses.KEY_RIGHT:
                if selected_idx < len(options):
                    selected_idx = len(options)
                elif selected_idx == len(options):
                    selected_idx = len(options) + 1
            elif key == curses.KEY_LEFT:
                if selected_idx == len(options) + 1:
                    selected_idx = len(options)
                elif selected_idx == len(options):
                    selected_idx -= 1
            elif key == curses.KEY_ENTER or key in [10, 13]:
                if selected_idx == len(options):  # 선택 버튼
                    if checked_idx >= 0:
                        return options[checked_idx]
                elif selected_idx == len(options) + 1:  # 취소 버튼
                    return None
                else:
                    checked_idx = selected_idx
            elif key == 27:  # ESC 키로 취소
                return None

    def input_screen(stdscr, title, input_label):
        curses.echo()
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        # Calculate starting y position for centered alignment
        start_y = (height - 5) // 2
        
        stdscr.addstr(start_y, (width // 2) - (len(title) // 2), title, curses.color_pair(2))
        stdscr.addstr(start_y + 2, (width // 2) - 10, input_label)
        stdscr.refresh()
        
        value = stdscr.getstr(start_y + 2, (width // 2) + 5, 60).decode('utf-8')  # Get user input
        
        select_str = '[선택]'
        cancel_str = '[취소]'
        selected_idx = 0
        
        while True:
            if selected_idx == 0:
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(start_y + 4, (width // 2) - 10, select_str)
                stdscr.attroff(curses.color_pair(1))
                stdscr.addstr(start_y + 4, (width // 2) + 4, cancel_str)
            else:
                stdscr.addstr(start_y + 4, (width // 2) - 10, select_str)
                stdscr.attron(curses.color_pair(1))
                stdscr.addstr(start_y + 4, (width // 2) + 4, cancel_str)
                stdscr.attroff(curses.color_pair(1))
            
            stdscr.refresh()
            key = stdscr.getch()
            
            if key == curses.KEY_LEFT and selected_idx > 0:
                selected_idx -= 1
            elif key == curses.KEY_RIGHT and selected_idx < 1:
                selected_idx += 1
            elif key == curses.KEY_ENTER or key in [10, 13]:
                if selected_idx == 0:  # 선택 버튼
                    return value
                elif selected_idx == 1:  # 취소 버튼
                    return None
            elif key == 27:  # ESC 키로 취소
                return None

    curses.start_color()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLACK)
    stdscr.keypad(True)

    os_options = ['UBUNTU', 'CENTOS', 'WINDOWS', 'REDHAT', 'DEBIAN']
    os_choice = selection_screen(stdscr, 'Select OS', os_options)
    if not os_choice:
        return

    middle_options = ['APACHE', ' DBMS ', 'TOMCAT', '선택 안 함']
    middle_choice = selection_screen(stdscr, 'Select Middleware', middle_options)
    if not middle_choice:
        return

    desc_choice = input_screen(stdscr, 'Enter Description', '별칭 입력: ')
    if desc_choice is None:
        return

    ip_choice = input_screen(stdscr, 'Enter IP (e.g., 123.456.789.111)', 'Enter IP: ')
    if ip_choice is None:
        return

    id_choice = input_screen(stdscr, 'Enter ID', 'Enter ID: ')
    if id_choice is None:
        return

    #pw_choice = input_screen(stdscr, 'Enter PW', 'Enter PW: ')
    #if pw_choice is None:
    #    return

    stdscr.clear()
    stdscr.addstr(0, 0, f'OS 선택: {os_choice}', curses.color_pair(2))
    stdscr.addstr(1, 0, f'Middleware 선택: {middle_choice}', curses.color_pair(2))
    stdscr.addstr(2, 0, f'Description 입력: {desc_choice}', curses.color_pair(2))
    stdscr.addstr(3, 0, f'IP 입력: {ip_choice}', curses.color_pair(2))
    stdscr.addstr(4, 0, f'ID 입력: {id_choice}', curses.color_pair(2))
    #stdscr.addstr(5, 0, f'PW 입력: {pw_choice}', curses.color_pair(2))
    stdscr.refresh()
    stdscr.getch()  # Pause to show selection

    with open('serverlist.cfg', 'a') as f:
        f.write(f'{os_choice} ; {middle_choice} ; {desc_choice} ; {ip_choice} ; {id_choice} \n')

# This would be the content of server_registration.py