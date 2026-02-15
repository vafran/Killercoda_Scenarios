# Disable terminal echo so script commands aren't shown
stty -echo

# Trap interrupts (Ctrl+C, Ctrl+Z) to prevent cancellation
trap '' SIGINT SIGTSTP

echo "Setting up environment... Please wait."

# Hide cursor
tput civis

spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )

while [ ! -f /tmp/background-finished ]; do
  for i in "${spinner[@]}"; do
    echo -ne "\r$i Setup in progress..."
    sleep 0.1
    # Check explicitly inside loop to avoid waiting for full spinner cycle
    if [ -f /tmp/background-finished ]; then
      break 2
    fi
  done
done

# Show cursor
tput cnorm
echo -e "\rDone! Environment is ready.      "

# Untrap signals
trap - SIGINT SIGTSTP
