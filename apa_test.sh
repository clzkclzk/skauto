#!/bin/bash

# 보고서 파일
REPORT_FILE="apache_audit_report.txt"

# 보고서 초기화
echo "Apache 취약점 점검 보고서" > $REPORT_FILE
echo "===============================================================================================================" >> $REPORT_FILE

# 초기화
GOOD_COUNT=0
BAD_COUNT=0
TOTAL_COUNT=0

# 점검 결과 카운트 함수
update_counts() {
    if [ "$1" == "양호" ]; then
        GOOD_COUNT=$((GOOD_COUNT + 1))
    else
        BAD_COUNT=$((BAD_COUNT + 1))
    fi
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
}

# 1.1 Apache 데몬 User와 Group 점검
check_apache_daemon_user_group() {
    echo "1.1 데몬 관리" >> $REPORT_FILE
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2/apache2.conf"
    APACHE_ENVVARS="/etc/apache2/envvars"

    # Apache User 및 Group 확인
    APACHE_USER=$(grep -E "^User" "$APACHE_CONF" | awk '{print $2}')
    APACHE_GROUP=$(grep -E "^Group" "$APACHE_CONF" | awk '{print $2}')

    # 환경 변수로 설정된 경우 실제 값 확인
    if [[ "$APACHE_USER" == "\${APACHE_RUN_USER}" ]]; then
        APACHE_USER=$(grep -E "^export APACHE_RUN_USER" "$APACHE_ENVVARS" | awk -F '=' '{print $2}')
    fi

    if [[ "$APACHE_GROUP" == "\${APACHE_RUN_GROUP}" ]]; then
        APACHE_GROUP=$(grep -E "^export APACHE_RUN_GROUP" "$APACHE_ENVVARS" | awk -F '=' '{print $2}')
    fi

    # Apache 데몬 계정 확인
    USER_INFO=$(grep "^$APACHE_USER:" /etc/passwd)

    # 로그인 가능 여부 확인
    if [[ "$USER_INFO" == *"/bin/bash"* || "$USER_INFO" == *"/bin/sh"* ]]; then
        LOGIN_STATUS="취약 -  로그인 가능한 전용 Web Server 계정으로 설정 및 데몬이 구동 중임"
        update_counts "취약"
    else
        LOGIN_STATUS="양호 -  로그인 불가한 전용 Web Server 계정으로 설정 및 데몬이 구동 중임"
        update_counts "양호"
    fi

    # 결과 보고서에 기록
    echo "Apache 데몬 User: $APACHE_USER" >> $REPORT_FILE
    echo "Apache 데몬 Group: $APACHE_GROUP" >> $REPORT_FILE
    echo "점검 결과: $LOGIN_STATUS" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE
}

# 1.2. 관리 서버 디렉터리 권한 설정
check_management_server_directory_permissions() {
    echo "1.2 관리 서버 디렉터리 권한 설정" >> $REPORT_FILE
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2/apache2.conf"

    # ServerRoot 경로를 확인하는 함수
    get_server_root() {
        SERVER_ROOT=$(grep -E "^ServerRoot" "$APACHE_CONF" | awk '{print $2}' | tr -d '"')
        if [ -z "$SERVER_ROOT" ]; then
            # ServerRoot가 설정 파일에 없다면 기본 경로 사용 (/etc/apache2)
            SERVER_ROOT="/etc/apache2"
        fi
        echo "$SERVER_ROOT"
    }

    # 디렉토리 권한을 확인하는 함수
    check_permissions() {
        DIR_PATH="$1"
        PERMISSIONS=$(ls -ld "$DIR_PATH")
        OWNER=$(echo "$PERMISSIONS" | awk '{print $3}')
        GROUP=$(echo "$PERMISSIONS" | awk '{print $4}')
        MODE=$(echo "$PERMISSIONS" | awk '{print $1}')

        # 권한을 숫자로 변환
        NUMERIC_MODE=$(stat -c "%a" "$DIR_PATH")

        # 진단 기준 평가
        if [ "$OWNER" == "www-data" ] && [ "$NUMERIC_MODE" -eq 750 ]; then
            RESULT="양호 - 전용 Web Server 계정 소유이고, 750(drwxr-x---) 권한임"
            update_counts "양호"
        else
            RESULT="취약 -"
            if [ "$OWNER" != "www-data" ]; then
                RESULT="$RESULT 1) 전용 Web Server 계정 소유가 아님"
            fi
            if [ "$NUMERIC_MODE" -ne 750 ]; then
                RESULT="$RESULT 2) 권한이 750(drwxr-x---) 초과임"
            fi
            update_counts "취약"
        fi

        # 결과 보고서에 기록
        echo "관리 서버 디렉터리: $DIR_PATH" >> "$REPORT_FILE"
        echo "소유자: $OWNER" >> "$REPORT_FILE"
        echo "그룹: $GROUP" >> "$REPORT_FILE"
        echo "권한: $MODE" >> "$REPORT_FILE"
        echo "점검 결과: $RESULT" >> "$REPORT_FILE"
        echo "===============================================================================================================" >> "$REPORT_FILE"
    }

    # 메인 스크립트 실행
    SERVER_ROOT=$(get_server_root)
    check_permissions "$SERVER_ROOT"
}

# 1.3. 설정 파일 권한 설정
check_config_file_permissions() {
    echo "1.3 설정 파일 권한 설정" >> "$REPORT_FILE"
    # Apache 설치 디렉터리
    APACHE_DIR="/etc/apache2"

    # 설정 파일들의 권한을 찾는 함수
    check_config_permissions() {
        local conf_files
        conf_files=$(find "$APACHE_DIR" -type f -name "*.conf")
        local any_vulnerable=false

        for file in $conf_files; do
            local permissions owner mode numeric_mode
            permissions=$(ls -l "$file")
            owner=$(echo "$permissions" | awk '{print $3}')
            mode=$(echo "$permissions" | awk '{print $1}')
            numeric_mode=$(stat -c "%a" "$file")

            # 진단 기준 평가
            if [ "$owner" == "www-data" ] && { [ "$numeric_mode" -eq 600 ] || [ "$numeric_mode" -eq 700 ]; }; then
                result="양호 - 전용 Web Server 계정 소유이고, rw-------(600) 또는 rwx------(700) 권한임"
            else
                result="취약 -"
                any_vulnerable=true
                if [ "$owner" != "www-data" ]; then
                    result="$result 1) 전용 Web Server 계정 소유가 아님"
                fi
                if [ "$numeric_mode" -ne 600 ] && [ "$numeric_mode" -ne 700 ]; then
                    result="$result 2) 권한이 rw-------(600) 또는 rwx------(700) 초과임"
                fi
            fi

            # 결과 보고서에 기록
            echo "설정 파일: $file" >> "$REPORT_FILE"
            echo "소유자: $owner" >> "$REPORT_FILE"
            echo "권한: $mode" >> "$REPORT_FILE"
            echo "점검 결과: $result" >> "$REPORT_FILE"
            echo "===============================================================================================================" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        done
        
        if $any_vulnerable; then
            update_counts "취약"
        else
            update_counts "양호"
        fi
    }

    # 메인 스크립트 실행
    check_config_permissions
}

# 1.4. 디렉터리 검색 기능 제거
check_directory_search() {
    echo "1.4 디렉터리 검색 기능 제거" >> "$REPORT_FILE"
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2/apache2.conf"

    # <Directory /var/www/> 지시어 내 Options 값을 확인하는 함수
    check_var_www_options() {
        local options_line
        options_line=$(awk '/<Directory \/var\/www\/>/,/<\/Directory>/{print}' "$APACHE_CONF" | grep -E "^\s*Options\s")
        
        if [ -n "$options_line" ]; then
            local dir="/var/www/"
            local options
            options=$(echo "$options_line" | awk '{print $2}')

            # 결과 보고서에 기록
            echo "디렉터리: $dir" >> "$REPORT_FILE"
            echo "Options 값: $options" >> "$REPORT_FILE"

            # 진단 기준 평가
            if [[ "$options" == *"Indexes"* ]]; then
                result="취약 - Indexes 옵션이 설정되어 있음"
                update_counts "취약"
            elif [[ "$options" == *"IncludesNoExec"* || "$options" == *"-Indexes"* ]]; then
                result="양호 - IncludesNoExec 또는 -Indexes 옵션이 설정되어 있음"
                update_counts "양호"
            else
                result="양호 - Indexes 옵션이 설정되어 있지 않음"
                update_counts "양호"
            fi

            # 결과 보고서에 기록
            echo "점검 결과: $result" >> "$REPORT_FILE"
            echo "===============================================================================================================" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    }

    # 메인 스크립트 실행
    check_var_www_options
}

# 1.5. 로그 디렉토리/파일 권한 설정
check_log_directory_permissions() {
    echo "1.5. 로그 디렉터리/파일 권한 설정" >> "$REPORT_FILE"
    # 로그 디렉토리 설정
    LOG_DIR="/var/log/apache2"

    # 초기 상태 설정
    any_vulnerable=false

    # 로그 디렉토리 권한 및 소유자 확인
    DIR_INFO=$(ls -ld "$LOG_DIR")
    DIR_PERMS=$(echo "$DIR_INFO" | awk '{print $1}')
    DIR_OWNER=$(echo "$DIR_INFO" | awk '{print $3}')

    if [[ "$DIR_PERMS" != "drwxr-x---" || "$DIR_OWNER" != "www-data" ]]; then
        any_vulnerable=true
        echo "로그 디렉토리 권한: $DIR_PERMS" >> "$REPORT_FILE"
        echo "로그 디렉토리 소유자: $DIR_OWNER" >> "$REPORT_FILE"
    fi

    # 로그 파일 권한 및 소유자 확인
    for FILE in $LOG_DIR/*; do
        if [ -f "$FILE" ]; then
            FILE_INFO=$(ls -l "$FILE")
            FILE_PERMS=$(echo "$FILE_INFO" | awk '{print $1}')
            FILE_OWNER=$(echo "$FILE_INFO" | awk '{print $3}')
            FILE_NAME=$(basename "$FILE")
            
            if [[ "$FILE_PERMS" != "-rw-r-----" || "$FILE_OWNER" != "www-data" ]]; then
                any_vulnerable=true
                echo "파일 이름: $FILE_NAME" >> "$REPORT_FILE"
                echo "파일 권한: $FILE_PERMS" >> "$REPORT_FILE"
                echo "파일 소유자: $FILE_OWNER" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
            fi
        fi
    done

    # 최종 상태 출력
    if $any_vulnerable; then
        echo "점검 결과: 취약 - 전용 Web Server 계정 소유가 아니거나, 디렉터리는 750, 파일은 640 권한을 초과함" >> "$REPORT_FILE"
        update_counts "취약"
    else
        echo "점검 결과: 양호 - 전용 Web Server 계정 소유이고, 디렉토리는 750, 파일은 640 권한으로 설정되어 있음" >> "$REPORT_FILE"
        update_counts "양호"
    fi
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.6. 로그 포맷 설정
check_log_formats() {
    echo "1.6 로그 포맷 설정" >> $REPORT_FILE
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2"

    # CustomLog 지시어를 이용해 로그 포맷 설정값을 확인하는 함수
    log_entries=$(grep -iR "CustomLog" /etc/apache2/ | grep -Ev '\s*#' | grep -Ev '\s*#.*CustomLog.*')
    local any_vulnerable=false

    # 각 로그 항목에 대해 처리
    while IFS= read -r entry; do
        filename=$(echo "$entry" | cut -d':' -f1)
        format=$(echo "$entry" | awk '{print $NF}')

        # 포맷 설정 값에 따라 진단 기준 평가
        if [[ "$format" == *"combined"* || "$format" == *"vhost_combined"* ]]; then
            result="양호 - Combined에 준하는 로그 포맷으로 설정됨"
        else
            result="취약 - Combined에 준하지 않는 로그 포맷으로 설정됨"
            any_vulnerable=true
        fi

        # 결과를 보고서에 기록
        echo "로그 포맷 설정 값: $format" >> "$REPORT_FILE"
        echo "파일 이름: $filename" >> "$REPORT_FILE"
        echo "진단 결과: $result" >> "$REPORT_FILE"
        echo "===============================================================================================================" >> "$REPORT_FILE"
    done <<< "$log_entries"
    
    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi
}

# 1.7. 로그 저장 주기
check_log_rotation() {
    echo "1.7 로그 저장 주기" >> $REPORT_FILE
    echo "진단 결과: 관리자 인터뷰 필요함." >> "$REPORT_FILE"
    echo "===============================================================================================================" >> "$REPORT_FILE"
    update_counts "양호" # 임시로 양호로 처리
}

# 1.8. 헤더 정보 노출 방지
check_header_info() {
    echo "1.8 헤더 정보 노출 방지" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    # Apache 설정 파일 경로
    SECURITY_CONF="/etc/apache2/conf-enabled/security.conf"

    # 설정 파일에서 주석 처리되지 않은 ServerTokens 및 ServerSignature 설정 값 확인
    server_tokens=$(grep -E '^\s*ServerTokens' "$SECURITY_CONF" | grep -vE '\s#' | awk '{print $2}')
    server_signature=$(grep -E '^\s*ServerSignature' "$SECURITY_CONF" | grep -vE '\s*#' | awk '{print $2}')
    sec_rule_engine=$(grep -E '^\s*SecRuleEngine' "$SECURITY_CONF" | grep -vE '\s*#' | awk '{print $2}')

    # 진단 기준에 따라 결과 계산
    if [[ "$server_tokens" == "Prod" && "$server_signature" == "Off" ]]; then
        status="양호 - ServerTokens가 Prod이고, ServerSignature가 Off로 설정됨"
        update_counts "양호"
    elif [[ "$sec_rule_engine" == "on" && "$server_tokens" == "Minimal" && "$server_signature" != "" ]]; then
        status="양호 - SecRuleEngine이 활성화되고, ServerTokens가 Minimal, ServerSignature 설정 값이 존재함"
        update_counts "양호"
    else
        status="취약 - ServerTokens가 Prod가 아니고, ServerSignature가 On이거나, SecRuleEngine on, ServerTokens Minimal, SecServerSignatue 설정 값이 존재하지 않음"
        update_counts "취약"
    fi

    # 결과 보고서에 기록
    echo "ServerTokens 설정 값: $server_tokens" >> "$REPORT_FILE"
    echo "ServerSignature 설정 값: $server_signature" >> "$REPORT_FILE"
    echo "진단 결과: $status" >> "$REPORT_FILE"
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.9 HTTP Method 제한
check_http_methods() {
    echo "1.9 HTTP Method 제한" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2"
    local any_vulnerable=false

    # LimitExcept 설정 확인
    echo "LimitExcept 설정 확인 결과:" >> "$REPORT_FILE"
    echo "-------------------------------------" >> "$REPORT_FILE"
    limit_except_results=$(grep -iR "LimitExcept" "$APACHE_CONF" | grep -vE '^\s*#' | awk '{print $NF}')
    if [[ -n "$limit_except_results" ]]; then
        echo "양호 - LimitExcept가 설정된 파일이 존재함." >> "$REPORT_FILE"
    else
        echo "취약 - LimitExcept가 설정된 파일이 존재하지 않음." >> "$REPORT_FILE"
        any_vulnerable=true
    fi
    echo "" >> "$REPORT_FILE"

    # TraceEnable 설정 확인
    echo "TraceEnable 설정 확인 결과:" >> "$REPORT_FILE"
    echo "-------------------------------------" >> "$REPORT_FILE"
    trace_enable_results=$(grep -iR "TraceEnable" "$APACHE_CONF" | grep -vE '^\s*#' | awk '{print $NF}')
    if [[ -n "$trace_enable_results" ]]; then
        echo "양호 - TraceEnable이 설정된 파일이 존재함." >> "$REPORT_FILE"
    else
        echo "취약 - TraceEnable이 설정된 파일이 존재하지 않음." >> "$REPORT_FILE"
        any_vulnerable=true
    fi
    echo "" >> "$REPORT_FILE"

    # Dav 설정 확인
    echo "Dav 설정 확인 결과:" >> "$REPORT_FILE"
    dav_results=$(grep -iR "Dav" "$APACHE_CONF" | grep -vE '^\s*#' | awk '{print $NF}')
    if [[ -n "$dav_results" ]]; then
        echo "양호 - Dav가 설정된 파일이 존재함." >> "$REPORT_FILE"
    else
        echo "취약 - Dav가 설정된 파일이 존재하지 않음." >> "$REPORT_FILE"
        any_vulnerable=true
    fi
    echo "" >> "$REPORT_FILE"

    # 최종 상태 출력
    if $any_vulnerable; then
        echo "진단 결과: 취약 - LimitExcept를 설정하지 않았거나 TraceEnable, Dav 설정 값이 On으로 설정됨." >> "$REPORT_FILE"
        update_counts "취약"
    else
        echo "진단 결과: 양호 - LimitExcept를 설정하거나 TraceEnable, Dav 설정 값이 Off로 설정됨." >> "$REPORT_FILE"
        update_counts "양호"
    fi
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.10 에러 메시지 관리
check_error_messages() {
    echo "1.10 에러 메시지 관리" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "필수 에러 코드 핸들링 설정 및 에러 페이지 존재 여부 확인:" >> "$REPORT_FILE"
    echo "-------------------------------------" >> "$REPORT_FILE"
    # 필수 에러 코드 핸들링 설정 및 에러 페이지 존재 여부 확인
    local any_vulnerable=false

    # 에러 코드 목록
    error_codes=("400" "401" "403" "404" "500")

    for code in "${error_codes[@]}"; do
        error_page=$(grep -iR "ErrorDocument.*$code" "$APACHE_CONF" | grep -vE '\s*#' | awk '{print $NF}')
        if [[ -n "$error_page" ]]; then
            echo "필수 에러 코드 $code 에 대한 핸들링이 설정되어 있습니다." >> "$REPORT_FILE"
        else
            echo "취약 - 필수 에러 코드 $code 에 대한 핸들링이 설정되어 있지 않습니다." >> "$REPORT_FILE"
            any_vulnerable=true
        fi
    done
    echo "" >> "$REPORT_FILE"

    if $any_vulnerable; then
        echo "진단 결과: 취약 - 필수 에러 코드 핸들링 설정 및 에러 페이지가 존재하지 않음." >> "$REPORT_FILE"
        update_counts "취약"
    else
        echo "진단 결과: 양호 - 필수 에러 코드 핸들링 설정 및 에러 페이지가 존재함." >> "$REPORT_FILE"
        update_counts "양호"
    fi
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.11 FollowSymLinks 옵션 비활성화
check_follow_symlinks() {
    echo "1.11 FollowSymLinks 옵션 비활성화" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    # Apache 설치 디렉터리
    APACHE_CONF_DIR="/etc/apache2"
    local any_vulnerable=false

    # FollowSymLinks 설정 여부를 저장하는 변수
    VULNERABLE_LINES=()
    SECURE_LINES=()

    # 설정 파일들을 재귀적으로 찾기
    CONFIG_FILES=$(find $APACHE_CONF_DIR -type f -name "*.conf")

    # 각 설정 파일에서 FollowSymLinks와 -FollowSymLinks 확인
    for FILE in $CONFIG_FILES; do
        while IFS= read -r line; do
            if [[ "$line" =~ FollowSymLinks ]]; then
                if [[ "$line" =~ -FollowSymLinks ]]; then
                    SECURE_LINES+=("$line")
                else
                    VULNERABLE_LINES+=("$line")
                fi
            fi
        done < <(grep "FollowSymLinks" "$FILE" | grep -v "#")
    done

    # 결과 출력
    if [ ${#VULNERABLE_LINES[@]} -gt 0 ]; then
        for line in "${VULNERABLE_LINES[@]}"; do
            echo "$line" >> "$REPORT_FILE"
        done
        echo "점검 결과: 취약 - FollowSymLinks 설정 존재 확인" >> "$REPORT_FILE"
        update_counts "취약"
    else
        for line in "${SECURE_LINES[@]}"; do
            echo "$line" >> "$REPORT_FILE"
        done
        echo "점검 결과: 양호 - -FollowSymLinks 설정이 존재하거나 FollowSymLinks 설정이 존재하지 않음" >> "$REPORT_FILE"
        update_counts "양호"
    fi
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.12 MultiViews 옵션 비활성화
check_multiviews() {
    echo "1.12 MultiViews 옵션 비활성화" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    # Apache 설정 디렉터리
    APACHE_CONF_DIR="/etc/apache2"
    local any_vulnerable=false

    # MultiViews 설정 여부를 저장하는 변수
    VULNERABLE_LINES=()
    SECURE_LINES=()

    # grep 명령어를 사용하여 설정 파일들에서 MultiViews와 -MultiViews 확인, available 디렉토리 제외
    while IFS= read -r line; do
        if [[ "$line" != *"available"* ]]; then
            if [[ "$line" =~ MultiViews ]]; then
                if [[ "$line" =~ -MultiViews ]]; then
                    SECURE_LINES+=("$line")
                else
                    VULNERABLE_LINES+=("$line")
                fi
            fi
        fi
    done < <(grep -iR "MultiViews" "$APACHE_CONF_DIR" | grep -v "#" | grep -v "available")

    # 결과 출력
    if [ ${#VULNERABLE_LINES[@]} -gt 0 ]; then
        for line in "${VULNERABLE_LINES[@]}"; do
            echo "$line" >> "$REPORT_FILE"
        done
        echo "점검 결과: 취약 - MultiViews 설정 존재 확인" >> "$REPORT_FILE"
        update_counts "취약"
    else
        for line in "${SECURE_LINES[@]}"; do
            echo "$line" >> "$REPORT_FILE"
        done
        echo "점검 결과: 양호 - -MultiViews 설정이 존재하거나 MultiViews 설정이 존재하지 않음" >> "$REPORT_FILE"
        update_counts "양호"
    fi
    echo "===============================================================================================================" >> "$REPORT_FILE"
}

# 1.13 상위 디렉터리 접근 금지 설정
check_directory_access() {
    echo "1.13 상위 디렉터리 접근 금지 설정" >> $REPORT_FILE
    # Apache 설정 파일 경로
    APACHE_CONF="/etc/apache2/conf-enabled/security.conf"

    # Apache 설정 파일에서 Directory 및 AllowOverride 관련 설정 추출
    settings=$(grep -E "Directory|AllowOverride" "$APACHE_CONF" | grep -vE '^\s*#')
    local any_vulnerable=false

    # 설정 점검 및 진단 기준 적용
    if echo "$settings" | grep -q "Options FollowSymLinks"; then
        STATUS="양호 - 상위 디렉터리에 이동 제한이 설정되어 있음"
    else
        STATUS="취약 - 상위 디렉터리에 이동 제한이 설정되어 있지 않음"
        any_vulnerable=true
    fi

    # 결과 보고서에 기록
    echo "점검 결과: $STATUS" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi
}

# 1.14 웹 서비스 영역 분리 설정
check_web_service_separation() {
    echo "1.14 웹 서비스 영역 분리 설정" >> $REPORT_FILE
    # 검색할 디렉터리
    APACHE_CONF_DIR="/etc/apache2"
    local any_vulnerable=false

    # 검색 명령어 실행 및 DocumentRoot 값 추출
    grep_output=$(grep -iR "DocumentRoot" $APACHE_CONF_DIR | grep -v '^Binary file')

    # 파일별로 처리
    while IFS= read -r line; do
        file_path=$(echo "$line" | cut -d ':' -f 1)
        document_root=$(echo "$line" | awk '{print $NF}')
        
        echo "파일 경로: $file_path ( $document_root )" >> $REPORT_FILE
    done <<< "$grep_output"

    # DocumentRoot 값이 /var/www/html인지 여부 확인
    if grep -qi "/var/www/html" <<< "$grep_output"; then
        STATUS="취약 - DocumentRoot이 기본 디렉터리로 설정되어 있습니다"
        any_vulnerable=true
    else
        STATUS="양호 - DocumentRoot이 유추할 수 없는 디렉터리로 설정되어 있습니다"
    fi

    # 결과 보고서에 기록
    echo "점검 결과: $STATUS" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi
}

# 2.1 불필요한 파일 삭제
check_unnecessary_files() {
    echo "2.1.불필요한 파일 삭제" >> $REPORT_FILE
    # Apache 설치 디렉터리
    APACHE_DIR="/etc/apache2"

    # 검사할 항목들 (표준 오류 출력을 무시하여 에러 메시지 억제)
    MANUAL_CHECK=$(find "$APACHE_DIR" -name manual 2>/dev/null)
    PRINTENV_CHECK=$(find "$APACHE_DIR/cgi-bin" -name printenv 2>/dev/null)
    TESTCGI_CHECK=$(find "$APACHE_DIR/cgi-bin" -name test-cgi 2>/dev/null)
    local any_vulnerable=false

    # 결과 변수 초기화
    RESULT="양호 - 불필요한 디렉터리 및 스크립트가 존재하지 않음."

    # 각 항목 검사 결과에 따라 결과 변수 수정
    if [ -n "$MANUAL_CHECK" ]; then
        RESULT="취약 - manual 디렉터리가 존재.: $MANUAL_CHECK"
        any_vulnerable=true
    elif [ -n "$PRINTENV_CHECK" ]; then
        RESULT="취약 - printenv 스크립트가 존재.: $PRINTENV_CHECK"
        any_vulnerable=true
    elif [ -n "$TESTCGI_CHECK" ]; then
        RESULT="취약 - test-cgi 스크립트가 존재.: $TESTCGI_CHECK"
        any_vulnerable=true
    fi

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi

    # 결과 출력
    echo "점검 결과: $RESULT" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE
}

# 2.2 기본 문서명 사용 제한
check_default_document() {
    echo "2.2.기본 문서명 사용 제한" >> $REPORT_FILE
    # Apache 설치 디렉터리
    APACHE_DIR="/etc/apache2"
    local any_vulnerable=false

    # Apache 디렉터리 내 모든 파일에서 DirectoryIndex 확인
    DIRECTORY_INDEX=$(grep -iR "DirectoryIndex" "$APACHE_DIR" 2>/dev/null)
    echo "$DIRECTORY_INDEX" >> $REPORT_FILE
    # 결과 변수 초기화
    RESULT="양호 - 기본 문서명이 index.html이 아님."

    # DirectoryIndex 검사 결과에 따라 결과 변수 수정
    if echo "$DIRECTORY_INDEX" | grep -q "index.html"; then
        RESULT="취약 - 기본 문서명이 index.html 확인."
        any_vulnerable=true
    fi

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi

    # 결과 출력
    echo "점검 결과: $RESULT" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE
}

# 2.3 SSL v3.0 POODLE 취약점
check_poodle_vulnerability() {
    echo "2.3.SSL v3.0 POODLE 취약점" >> $REPORT_FILE
    # Apache 설치 디렉터리
    APACHE_DIR="/etc/apache2"
    local any_vulnerable=false

    # Apache 디렉터리 내 모든 파일에서 SSLProtocol 확인
    SSL_PROTOCOL=$(grep -iR "SSLProtocol" "$APACHE_DIR" 2>/dev/null)

    # 결과 변수 초기화
    RESULT="취약 - 암호화 통신 프로토콜에서 TLS가 설정되어 있지 않음."

    # SSLProtocol 검사 결과에 따라 결과 변수 수정
    if echo "$SSL_PROTOCOL" | grep -q "TLS"; then
        RESULT="양호 - 암호화 통신 프로토콜에서 TLS가 설정되어 있음."
    else
        any_vulnerable=true
    fi

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi

    # 결과 출력
    echo "SSLProtocol 설정:" >> $REPORT_FILE
    echo "$SSL_PROTOCOL" >> $REPORT_FILE
    echo "점검 결과: $RESULT" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE
}

# 3.1 보안 패치 적용
check_security_patch() {
    echo "3.1.보안 패치 적용" >> $REPORT_FILE
    # Apache 권고 기준 버전
    RECOMMENDED_VERSION="2.4.51"
    local any_vulnerable=false

    # 현재 Apache 버전 확인
    CURRENT_VERSION=$(apache2 -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)

    # 결과 변수 초기화
    RESULT="취약 - Apache 권고 기준 이상 버전을 적용 중이지 않음."

    # 버전 비교
    if [ "$(printf '%s\n' "$RECOMMENDED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$RECOMMENDED_VERSION" ]; then
        RESULT="양호 - Apache 권고 기준 이상 버전 적용 중."
    else
        any_vulnerable=true
    fi

    if $any_vulnerable; then
        update_counts "취약"
    else
        update_counts "양호"
    fi

    # 결과 출력
    echo "현재 Apache 버전: $CURRENT_VERSION" >> $REPORT_FILE
    echo "점검 결과: $RESULT" >> $REPORT_FILE
    echo "===============================================================================================================" >> $REPORT_FILE
}

# 각 진단 함수 실행
check_apache_daemon_user_group
check_management_server_directory_permissions
check_config_file_permissions
check_directory_search
check_log_directory_permissions
check_log_formats
check_log_rotation
check_header_info
check_http_methods
check_error_messages
check_follow_symlinks
check_multiviews
check_directory_access
check_web_service_separation
check_unnecessary_files
check_default_document
check_poodle_vulnerability
check_security_patch

# 최종 결과 요약
echo "--------------------------결과------------------------" >> $REPORT_FILE
echo "총 항목 수 : $TOTAL_COUNT" >> $REPORT_FILE
echo "양호 : $GOOD_COUNT" >> $REPORT_FILE
echo "취약 : $BAD_COUNT" >> $REPORT_FILE
echo "===============================================================================================================" >> $REPORT_FILE

# 결과 출력
cat "$REPORT_FILE"