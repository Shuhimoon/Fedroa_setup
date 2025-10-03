if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Set welcome message
function fish_greeting
    echo Hello (whoami)~~~
    fastfetch
end
