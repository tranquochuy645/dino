#!/bin/bash

declare -A matrix
declare -A obstacles_positions

SIG_UP=USR1   #for interprocess communication
SIG_QUIT=KILL #kill signal
SIG_DEAD=HUP  #hangup

alive=1
score=0

N_ROW=5
N_COL=80

CHARACTER="🦖"
OBSTACLE="🌵"
EMPTY="｜"

jump_count=0
obstacles_count=10

char_col=3 # initial position of character
char_row=0
jump_force=0
jump_sig=0

init_matrix() { # initialize matrix
    for ((i = $N_ROW; i >= 0; i--)); do
        for ((j = $N_COL; j >= 0; j--)); do
            matrix[$i, $j]=$EMPTY
        done
    done
    matrix[$char_row, $char_col]=$CHARACTER
}
#${matrix[row_index][column_index]}
getchar() {
    trap "" SIGINT SIGQUIT
    trap "return;" $SIG_DEAD

    while true; do
        read -s -n 1 key # -s silent mode, -n nchars (just 1 character)
        case "$key" in
        [qQ])
            kill -$SIG_QUIT $game_loop_pid # sends quit signal to the game process
            return
            ;;
        [wW])
            kill -$SIG_UP $game_loop_pid # jump key
            ;;
        esac
    done
}

move_char() {
    if [ $jump_sig -eq 1 ] && [ $char_row -eq 0 ]; then
        jump_force=3
        jump_sig=0
    fi

    if [ $jump_force -gt 1 ]; then
        matrix[$char_row, $char_col]=$EMPTY
        matrix[$(($char_row + 1)), $char_col]=$CHARACTER
        char_row=$(($char_row + 1))
        jump_force=$(($jump_force - 1))
    else
        if [ $jump_force -eq 1 ]; then
            matrix[$char_row, $char_col]=$CHARACTER
            jump_force=$(($jump_force - 1))
        else
            if [ $char_row -gt 0 ]; then
                matrix[$char_row, $char_col]=$EMPTY
                matrix[$(($char_row - 1)), $char_col]=$CHARACTER
                char_row=$(($char_row - 1))
            fi
        fi
    fi

}

print_game() {
    if [ $char_row -eq 0 ]; then
        if [ "$(printf "%s" "${matrix[$char_row, $char_col]}")" != "$CHARACTER" ]; then
            alive=0
        fi
    fi
    temp=""
    for ((i = $N_ROW; i > 0; i--)); do
        for ((j = $N_COL; j >= 0; j--)); do
            temp+=${matrix[$i, $j]}
        done
        temp+="\n"
    done
    for ((j = $N_COL; j >= 0; j--)); do #last row
        temp+=${matrix[0, $j]}
    done
    echo -e "$temp"

}

init_obstacles() {
    obstacles_positions[0]=$N_COL
    for ((i = 1; i < $obstacles_count; i++)); do
        rand_value=$(($RANDOM % 11 + 10))
        let obstacles_positions[$i]=${obstacles_positions[$(($i - 1))]}+$rand_value
    done
}

generate_obstacles() {
    obstacle_row=0
    for ((i = 0; i < $obstacles_count; i++)); do
        t_posit=${obstacles_positions[$i]}
        matrix[$obstacle_row, $(($t_posit + 1))]=$EMPTY
        matrix[$obstacle_row, $(($t_posit))]=$OBSTACLE
        matrix[$obstacle_row, $(($t_posit - 1))]=$EMPTY
        let obstacles_positions[$i]-=1
        if [ ${obstacles_positions[$i]} -lt 0 ]; then
            matrix[$obstacle_row, $(($t_posit))]=$EMPTY
            rand_value=$(($RANDOM % 50 + 40))
            let obstacles_positions[$i]=$N_COL+50+$rand_value
        fi
    done
}

game_loop() {
    trap "jump_sig=1;" $SIG_UP # catch jump signal
    trap "exit 1;" $SIG_QUIT   # catch exit signal
    while [ "$alive" -eq 1 ]; do
        score=$(($score+1))
        move_char # calc
        generate_obstacles
        clear      # clear frame
        echo "Press w to jump"
        echo "Press q to quit"
        echo "Your score: $score"
        print_game # print frame
        sleep 0.1
    done

    echo "You Lost!!!!!!!!"
    kill -$SIG_DEAD $$ # $$ the process id of the script
}

init_matrix
init_obstacles

print_game

game_loop & # subprocess
game_loop_pid=$!

getchar

# exit 0
