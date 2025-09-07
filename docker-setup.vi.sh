#!/bin/sh
# Tác giả script@VanillaNahida
# File này dùng để tải về tự động các file cần thiết và tạo thư mục
# Tạm thời chỉ hỗ trợ bản Ubuntu X86, hệ thống khác chưa được thử nghiệm

# Định nghĩa hàm xử lý ngắt
handle_interrupt() {
    echo ""
    echo "Cài đặt đã bị ngắt bởi người dùng (Ctrl+C hoặc Esc)"
    echo "Nếu cần cài lại, hãy chạy script một lần nữa"
    exit 1
}

# Cài đặt bắt tín hiệu, xử lý Ctrl+C
trap handle_interrupt SIGINT

# Xử lý phím Esc
# Lưu lại cấu hình terminal
old_stty_settings=$(stty -g)
# Cấu hình terminal phản hồi ngay, không hiện ký tự
stty -icanon -echo min 1 time 0

# Phát hiện phím Esc, kích hoạt xử lý ngắt
(while true; do
    read -r key
    if [[ $key == $'\e' ]]; then
        # Phát hiện phím Esc, kích hoạt xử lý ngắt
        kill -SIGINT $$
        break
    fi
done) &

# Khi script kết thúc thì khôi phục lại cấu hình terminal
trap 'stty "$old_stty_settings"' EXIT


# In ký tự màu nghệ thuật
echo -e "\e[1;32m"  # Đặt màu xanh lá sáng
cat << "EOF"
Tác giả script：@Bilibili 香草味的纳西妲喵
 __      __            _  _  _            _   _         _      _      _        
 \ \    / /           (_)| || |          | \ | |       | |    (_)    | |       
  \ \  / /__ _  _ __   _ | || |  __ _    |  \| |  __ _ | |__   _   __| |  __ _ 
   \ \/ // _` || '_ \ | || || | / _` |   | . ` | / _` || '_ \ | | / _` | / _` |
    \  /| (_| || | | || || || || (_| |   | |\  || (_| || | | || || (_| || (_| |
     \/  \__,_||_| |_||_||_||_| \__,_|   |_| \_| \__,_||_| |_||_| \__,_| \__,_|                                                                                                                                                                                                                               
Biên dịch Tony Tran - https://github.com/thanhtantran (Orange Pi Vietnam)
EOF
echo -e "\e[0m"  # Khôi phục lại màu
echo -e "\e[1;36m  Script cài đặt tự động toàn bộ dịch vụ Xiaozhi Ver 0.2 cập nhật ngày 20/08/2025 \e[0m\n"
sleep 1



# Kiểm tra và cài whiptail
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        echo "Đang cài đặt whiptail..."
        apt update
        apt install -y whiptail
    fi
}

check_whiptail

# Tạo hộp thoại xác nhận
whiptail --title "Xác nhận cài đặt" --yesno "Sắp cài đặt dịch vụ Xiaozhi, có muốn tiếp tục không?" \
  --yes-button "Tiếp tục" --no-button "Thoát" 10 50

# Thực hiện theo lựa chọn của người dùng
case $? in
  0)
    ;;
  1)
    exit 1
    ;;
esac

# Kiểm tra quyền root
if [ $EUID -ne 0 ]; then
    whiptail --title "Lỗi quyền hạn" --msgbox "Hãy chạy script này với quyền root" 10 50
    exit 1
fi

# Kiểm tra phiên bản hệ thống
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
        whiptail --title "Lỗi hệ thống" --msgbox "Script này chỉ hỗ trợ chạy trên hệ thống Debian/Ubuntu" 10 60
        exit 1
    fi
else
    whiptail --title "Lỗi hệ thống" --msgbox "Không thể xác định phiên bản hệ thống. Script này chỉ hỗ trợ chạy trên hệ thống Debian/Ubuntu" 10 60
    exit 1
fi

# Hàm tải file cấu hình
check_and_download() {
    local filepath=$1
    local url=$2
    if [ ! -f "$filepath" ]; then
        if ! curl -fL --progress-bar "$url" -o "$filepath"; then
            whiptail --title "Lỗi" --msgbox "${filepath} Tải file thất bại" 10 50
            exit 1
        fi
    else
        echo "${filepath} File đã tồn tại, bỏ qua tải xuống"
    fi
}

# Kiểm tra đã cài đặt chưa
check_installed() {
    # Kiểm tra xem thư mục có tồn tại và không rỗng không
    if [ -d "/opt/xiaozhi-server/" ] && [ "$(ls -A /opt/xiaozhi-server/)" ]; then
        DIR_CHECK=1
    else
        DIR_CHECK=0
    fi
    
    # Kiểm tra xem container có tồn tại không
    if docker inspect xiaozhi-esp32-server > /dev/null 2>&1; then
        CONTAINER_CHECK=1
    else
        CONTAINER_CHECK=0
    fi
    
    # Cả hai lần kiểm tra đều thành công
    if [ $DIR_CHECK -eq 1 ] && [ $CONTAINER_CHECK -eq 1 ]; then
        return 0  # Đã Cài đặt
    else
        return 1  # Chưa cài đặt
    fi
}

# Cập nhật liên quan
if check_installed; then
    if whiptail --title "Phát hiện đã cài đặt" --yesno "Phát hiện dịch vụ Xiaozhi đã cài, có muốn nâng cấp không?" 10 60; then
        # Người dùng chọn nâng cấp và thực hiện các thao tác dọn dẹp
        echo "Bắt đầu nâng cấp..."
        
        # Dừng và xóa tất cả các dịch vụ Docker Compose
        docker compose -f /opt/xiaozhi-server/docker-compose_all.yml down
        
        # Dừng và xóa các container cụ thể (tính cả các container có thể không tồn tại)
        containers=(
            "xiaozhi-esp32-server"
            "xiaozhi-esp32-server-web"
            "xiaozhi-esp32-server-db"
            "xiaozhi-esp32-server-redis"
        )
        
        for container in "${containers[@]}"; do
            if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                docker stop "$container" >/dev/null 2>&1 && \
                docker rm "$container" >/dev/null 2>&1 && \
                echo "Xóa container thành công: $container"
            else
                echo "Container không tồn tại, bỏ qua: $container"
            fi
        done
        
        # Xóa một hình ảnh cụ thể (có tính đến khả năng hình ảnh có thể không tồn tại)
        images=(
            "ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:server_latest"
            "ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:web_latest"
        )
        
        for image in "${images[@]}"; do
            if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image}$"; then
                docker rmi "$image" >/dev/null 2>&1 && \
                echo "Xóa image thành công: $image"
            else
                echo "Image không tồn tại, bỏ qua: $image"
            fi
        done
        
        echo "Hoàn tất xóa dọn"
        
        # Sao lưu file cấu hình gốc
        mkdir -p /opt/xiaozhi-server/backup/
        if [ -f /opt/xiaozhi-server/data/.config.yaml ]; then
            cp /opt/xiaozhi-server/data/.config.yaml /opt/xiaozhi-server/backup/.config.yaml
            echo "Đã sao lưu file cấu hình gốc vào /opt/xiaozhi-server/backup/.config.yaml"
        fi
        
        # Tải xuống phiên bản mới nhất của tệp cấu hình
        check_and_download "/opt/xiaozhi-server/docker-compose_all.yml" "https://ghfast.top/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/docker-compose_all.yml"
        check_and_download "/opt/xiaozhi-server/data/.config.yaml" "https://ghfast.top/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/config_from_api.yaml"
        
        # Khởi động dịch vụ Docker
        echo "Bắt đầu khởi động phiên bản dịch vụ mới..."
        # Đánh dấu quá trình nâng cấp đã hoàn tất và bỏ qua các bước tải xuống tiếp theo
        UPGRADE_COMPLETED=1
        docker compose -f /opt/xiaozhi-server/docker-compose_all.yml up -d
    else
          whiptail --title "Bỏ qua nâng cấp" --msgbox "Đã hủy nâng cấp. Sử dụng phiên bản hiện tại." 10 50
          # Đã hủy nâng cấp. Sử dụng phiên bản hiện tại.
    fi
fi


# Kiểm tra cài đặt curl
if ! command -v curl &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "Không phát hiện curl, đang cài đặt..."
    apt update
    apt install -y curl
else
    echo "------------------------------------------------------------"
    echo "curl đã được cài, bỏ qua"
fi

# Kiểm tra cài đặt Docker
if ! command -v docker &> /dev/null; then
    echo "------------------------------------------------------------"
    echo "Không phát hiện Docker, đang cài đặt..."
    
    # Dùng mirror chính thức ẩn mirror nội địa
    DISTRO=$(lsb_release -cs)
    #MIRROR_URL="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
    #GPG_URL="https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
	MIRROR_URL="https://download.docker.com/linux/ubuntu"
    GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
    
    # Cài đặt phụ thuộc cơ bản
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
    
    # Tạo thư mục key và thêm key mirror nội địa
    mkdir -p /etc/apt/keyrings
    curl -fsSL "$GPG_URL" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Thêm mirror nội địa
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $MIRROR_URL $DISTRO stable" \
        > /etc/apt/sources.list.d/docker.list
    
    # Thêm key nguồn chính thức dự phòng (tránh lỗi xác minh key nội địa)
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7EA0A9C3F273FCD8 2>/dev/null || \
    echo "Cảnh báo: Một số khóa không được thêm vào. Vui lòng thử cài đặt bằng tay"
    
    # Cài đặt Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    
    # Khởi động dịch vụ
    systemctl start docker
    systemctl enable docker
    
    # Kiểm tra cài đặt thành công chưa
    if docker --version; then
        echo "------------------------------------------------------------"
        echo "Cài đặt Docker hoàn tất!"
    else
        whiptail --title "Lỗi" --msgbox "Cài đặt Docker không thành công, vui lòng kiểm tra nhật ký" 10 50
        exit 1
    fi
else
    echo "Docker đã được cài, bỏ qua"
fi

# Cấu hình nguồn Docker mirror
MIRROR_OPTIONS=(
	"1" "Xuanyuan Mirror (Khuyến nghị)"
	"2" "Nguồn Tencent Cloud Mirror"
	"3" "Nguồn USTC Mirror"
	"4" "Nguồn NetEase 163 Mirror"
	"5" "Nguồn Huawei Cloud Mirror"
	"6" "Nguồn Alibaba Cloud Mirror"
    "7" "Mirror tự chọn"
    "8" "Bỏ qua cấu hình"
)

MIRROR_CHOICE=$(whiptail --title "Chọn nguồn mirror Docker" --menu "Hãy chọn nguồn mirror Docker cần dùng" 20 60 10 \
"${MIRROR_OPTIONS[@]}" 3>&1 1>&2 2>&3) || {
    echo "Không chọn gì? Thoát"
    exit 1
}

case $MIRROR_CHOICE in
    1) MIRROR_URL="https://docker.xuanyuan.me" ;; 
    2) MIRROR_URL="https://mirror.ccs.tencentyun.com" ;; 
    3) MIRROR_URL="https://docker.mirrors.ustc.edu.cn" ;; 
    4) MIRROR_URL="https://hub-mirror.c.163.com" ;; 
    5) MIRROR_URL="https://05f073ad3c0010ea0f4bc00b7105ec20.mirror.swr.myhuaweicloud.com" ;; 
    6) MIRROR_URL="https://registry.aliyuncs.com" ;; 
    7) MIRROR_URL=$(whiptail --title "Mirror tự chọn" --inputbox "Hãy nhập đầy đủ URL mirror:" 10 60 3>&1 1>&2 2>&3) ;; 
    8) MIRROR_URL="" ;; 
esac

if [ -n "$MIRROR_URL" ]; then
    mkdir -p /etc/docker
    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    fi
    cat > /etc/docker/daemon.json <<EOF
{
    "dns": ["8.8.8.8", "114.114.114.114"],
    "registry-mirrors": ["$MIRROR_URL"]
}
EOF
    whiptail --title "Cấu hình thành công" --msgbox "Đã thêm mirror thành công: $MIRROR_URL\nẤn Enter để khởi động lại Docker và Tiếp tục..." 12 60
    echo "------------------------------------------------------------"
    echo "Bắt đầu khởi động lại Docker..."
    systemctl restart docker.service
fi

# Tạo thư mục cài đặt
echo "------------------------------------------------------------"
echo "Tạo thư mục cài đặt..."
# Kiểm tra và tạo thư mục dữ liệu
if [ ! -d /opt/xiaozhi-server/data ]; then
    mkdir -p /opt/xiaozhi-server/data
    echo "Đã tạo thư mục dữ liệu: /opt/xiaozhi-server/data"
else
    echo "Thư mục xiaozhi-server/data đã tồn tại, bỏ qua bước tạo"
fi

# Kiểm tra và tạo thư mục mô hình
if [ ! -d /opt/xiaozhi-server/models/SenseVoiceSmall ]; then
    mkdir -p /opt/xiaozhi-server/models/SenseVoiceSmall
    echo "Đã tạo thư mục mô hình: /opt/xiaozhi-server/models/SenseVoiceSmall"
else
    echo "Thư mục xiaozhi-server/models/SenseVoiceSmall đã tồn tại, bỏ qua bước tạo"
fi

echo "------------------------------------------------------------"
echo "Bắt đầu tải mô hình nhận dạng giọng nói"
# Tải file mô hình
MODEL_PATH="/opt/xiaozhi-server/models/SenseVoiceSmall/model.pt"
if [ ! -f "$MODEL_PATH" ]; then
    (
    for i in {1..20}; do
        echo $((i*5))
        sleep 0.5
    done
    ) | whiptail --title "Tải mô hình" --gauge "Bắt đầu tải mô hình nhận dạng giọng nói..." 10 60 0
    curl -fL --progress-bar https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt -o "$MODEL_PATH" || {
        whiptail --title "Lỗi" --msgbox "model.pt Tải file thất bại" 10 50
        exit 1
    }
else
    echo "model.ptFile đã tồn tại, bỏ qua tải xuống"
fi

# Nếu không phải nâng cấp xong thì mới tải
if [ -z "$UPGRADE_COMPLETED" ]; then
    check_and_download "/opt/xiaozhi-server/docker-compose_all.yml" "https://ghfast.top/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/docker-compose_all.yml"
    check_and_download "/opt/xiaozhi-server/data/.config.yaml" "https://ghfast.top/https://raw.githubusercontent.com/xinnan-tech/xiaozhi-esp32-server/refs/heads/main/main/xiaozhi-server/config_from_api.yaml"
fi

# Khởi động dịch vụ Docker
(
echo "------------------------------------------------------------"
echo "Đang tải image Docker..."
echo "Việc này có thể mất vài phút, vui lòng chờ"
docker compose -f /opt/xiaozhi-server/docker-compose_all.yml up -d

if [ $? -ne 0 ]; then
    whiptail --title "Lỗi" --msgbox "Dịch vụ Docker không khởi động được, vui lòng thử thay đổi nguồn hình ảnh và chạy lại tập lệnh này" 10 60
    exit 1
fi

echo "------------------------------------------------------------"
echo "Đang kiểm tra trạng thái dịch vụ..."
TIMEOUT=300
START_TIME=$(date +%s)
while true; do
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
        whiptail --title "Lỗi" --msgbox "Dịch vụ khởi động quá lâu, không tìm thấy log mong đợi trong thời gian quy định" 10 60
        exit 1
    fi
    
    if docker logs xiaozhi-esp32-server-web 2>&1 | grep -q "Started AdminApplication in"; then
        break
    fi
    sleep 1
done

    echo "Server đã khởi động thành công! Đang hoàn tất cấu hình..."
    echo "Khởi động dịch vụ..."
    docker compose -f /opt/xiaozhi-server/docker-compose_all.yml up -d
    echo "Khởi động dịch vụ hoàn tất!"
)

# Cấu hình secret key

# Lấy địa chỉ IP công cộng của server
PUBLIC_IP=$(hostname -I | awk '{print $1}')
whiptail --title "Cấu hình khóa server" --msgbox "Hãy dùng trình duyệt truy cập link bên dưới để mở bảng điều khiển và đăng ký tài khoản: \n\nĐịa chỉ nội bộ：http://127.0.0.1:8002/\nĐịa chỉ công cộng：http://$PUBLIC_IP:8002/ (Nếu là cloud server, hãy mở port trong security group 8000 8001 8002)。\n\nNgười dùng đăng ký đầu tiên sẽ là quản trị viên, các tài khoản sau là người dùng thường. Người dùng thường chỉ được liên kết thiết bị và cấu hình agent; quản trị viên có thể quản lý model, người dùng và tham số.\n\nSau khi đăng ký, vui lòng nhấn Enter" 18 70
SECRET_KEY=$(whiptail --title "Máy chủ" --inputbox "Vui lòng sử dụng tài khoản quản trị viên cấp cao để đăng nhập vào bảng điều khiển thông minh.\nTruy cập máy chủ: http://127.0.0.1:8002/\nTruy cập máy chủ: http://$PUBLIC_IP:8002/\nTrong menu trên cùng, Từ điển tham số → Quản lý tham số, tìm mã tham số: server.secret (Khóa máy chủ). \nSao chép giá trị tham số và nhập vào ô nhập bên dưới.\n\nVui lòng nhập khóa (để trống cho Khóa máy chủ):" 15 60 3>&1 1>&2 2>&3)

if [ -n "$SECRET_KEY" ]; then
    python3 -c "
import sys, yaml; 
config_path = '/opt/xiaozhi-server/data/.config.yaml'; 
with open(config_path, 'r') as f: 
    config = yaml.safe_load(f) or {}; 
config['manager-api'] = {'url': 'http://xiaozhi-esp32-server-web:8002/xiaozhi', 'secret': '$SECRET_KEY'}; 
with open(config_path, 'w') as f: 
    yaml.dump(config, f); 
"
    docker restart xiaozhi-esp32-server
fi

# Lấy và hiển thị thông tin địa chỉ
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Sửa lỗi không lấy được ws trong log, thay bằng hardcode
whiptail --title "Cài đặt hoàn tất!" --msgbox "\
Địa chỉ dịch vụ như sau:\n\
Địa chỉ truy cập admin: http://$LOCAL_IP:8002\n\
OTA: http://$LOCAL_IP:8002/xiaozhi/ota/\n\
Địa chỉ API phân tích hình ảnh: http://$LOCAL_IP:8003/mcp/vision/explain\n\
WebSocket: ws://$LOCAL_IP:8000/xiaozhi/v1/\n\
\nQuá trình cài đặt hoàn tất! Cảm ơn bạn đã sử dụng! \nNhấn Enter... " 16 70
