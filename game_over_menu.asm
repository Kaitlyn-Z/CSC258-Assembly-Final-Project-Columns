################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Yibin Wang, 1010568173
# Student 2: Kaitlyn Zhu, 1010847372
#
# We assert that the code submitted here is entirely our own
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    258
# - Display height in pixels:   258
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

##############################################################################
# Constants & Colors
##############################################################################
.eqv ROW_SIZE     128           # 32 units * 4 bytes

.data
    displayaddress:     .word       0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

    # Palette Array for Random Selection
    palette: .word 0xf56527, 0xffd72b, 0xcff5a4, 0x61e5fa, 0x8365f0, 0xfcadff
    grid_color: .word 0x808080    # Gray for boundaries
    black_palette: .word 0x000000, 0x000000, 0x000000 # A palette with only black - for repaiting grid cells
    
    # Palette for text
    text_color: .word 0xffffff  # White text
    text_box_color: .word 0x202020  # Dark grey for text boxes
    
    # Parameters for the playing field:
    # Information about the grid
    grid_x_offset: .word 4
    grid_y_offset: .word 4
    grid_width:    .word 11             # Playable width (excluding walls)
    grid_height:   .word 20             # Playable height (excluding walls)
    grid_full_wid: .word 13             # Playable width + 2
    grid_full_hei: .word 22             # Playable height + 2

    # Parameters calculated for drawing playing field
    grid_left: .word 4                  # Same as x_offset
    grid_right: .word 16                # (left + width + 1) 
    grid_top: .word 4                   # Same as y_offset
    grid_bot: .word 25                  # (top + height + 1)

    # Parameters for current/next column diplay OUTSIDE of playing field
    display_x: .word 20                 # grid_right + 4
    display_y: .word 10     
    
    # Gravity threshold
    gravity_threshold: .word 30

##############################################################################
# Mutable Data - Game State (Memory Variables)
##############################################################################
    curr_col_x:  .word 10               # Initializing X point for column: middle of grid ceiling
    curr_col_y:  .word 5                # Initializing Y point for column: one block beneath the grid ceiling
    gem1_color:  .word 0                # Color of the gems 
    gem2_color:  .word 0
    gem3_color:  .word 0

    # The Grid (220 words for 11x20 field)
    grid: .word 0:220
    
    # An identical copy of the playing field (for recording of pixels to be eliminated)
    match_grid: .word 0:220
    
    # Gravity counter
    gravity_counter: .word 0

    # Current game state
    # 0 = Playing
    # 1 = Paused
    # 2 = Main Menu
    # 3 = Game Over & Restart
    game_state: .word 2

.text
.globl main

# NOTE: Calculation for bitmap address = base address + (Y*row_size_bytes) + X*4
#       MAKE AN EXCEL SHEET to keep track of the status of registers during each function!!

##############################################################################
# Main Program Execution
#   $a0 = The X coordinate of the column (being painted) & time for sleep
#   $a1 = The Y coordinate of the column (being painted)
#   $t0 = default display address + keyboard address
#   $t1 = current position of topmost gem (where to draw col)
#   $t2 = status of the keyboard (whether there is key-press & what key it is)
##############################################################################
main:
    jal clear_screen                    # Clear screen
    jal draw_main_menu                  # Draw main menu at beginning
    j game_loop
    
# Create a game loop - updating ~60 times per second
game_loop:
    # Check the keyboard for inputs
    lw $t0, ADDR_KBRD                   # Go to the keyboard address
    lw $t2, 0($t0)                      # Get the first word to check input
    
    # Check if state is in game over state (state = 3)
    lw $t3, game_state                  # Load current game state
    li $t4, 3
    bne $t3, $t4, check_menu_state      # Check if in main menu, etc.
    
    # Runs if game is in game over state
    beq $t2, $zero, skip_input          # If no key pressed, skip and loop
    lw $t2, 4($t0)                      # Read key
    beq $t2, 0x72, restart_game         # If the key is "R", restart the game
    beq $t2, 0x71, quit_game            # If the key is "Q", quit the game
    j skip_input

# Check if in main menu
check_menu_state:
    li $t4, 2
    bne $t3, $t4, check_play_pause      # If not in main menu, play normally

    beq $t2, $zero, skip_input          # If no key pressed, skip and loop
    
    lw $t2, 4($t0)
    beq $t2, 0x20, start_from_menu      # If space is pressed, start game
    j skip_input

# Handles key presses if in playing or paused state
check_play_pause:
    # No key pressed
    beq $t2, $zero, handle_gravity      # If no key pressed, drop column down (if not paused)
    
    # If key has been pressed: compute movement based on key
    lw $t2, 4($t0)                      # Get the value of key
    beq $t2, 0x70, handle_pause         # If the key is "P", handle pause logic
    
    # Check game state
    lw $t3, game_state                  # Load current game state
    bne $t3, $zero, skip_input          # If paused (state 1), ignore move keys

    # Handle movement    
    beq $t2, 0x61, move_left            # If the key is "A", move left
    beq $t2, 0x64, move_right           # If the key is "D", move right
    beq $t2, 0x77, shuffle_col          # If the key is "W", shuffle the column
    beq $t2, 0x73, drop_at_once         # If the key is "S", drop the column all the way down
    beq $t2, 0x71, quit_game            # If the key is "Q", quit game
    
handle_gravity:    
    # Check if game state is 1 (paused)
    lw $t3, game_state                  # Load game state
    bne $t3, $zero, skip_input
    
    # Continue applying gravity if game currently playing (state 0)
    # Handle gravity timer
    lw $t0, gravity_counter             # Load in counter
    lw $t1, gravity_threshold           # Load in threshold for counter to reach before dropping block
    addi $t0, $t0, 1                    # Increment counter

    blt $t0, $t1, update_timer          # Check if counter is less than threshold
    
    # Threshold reached: move column down by 1
    sw $zero, gravity_counter           # Reset counter
    jal move_down                       # Move column down by 1
    j skip_input

update_timer:
    sw $t0, gravity_counter             # Save value of gravity counter since not at threshold

skip_input:
    li $a0, 16                          # Sleep for a certain amount of time
    li $v0, 32                          # Call sleep
    syscall

    j game_loop                         # Repeat the process
    
handle_pause:
    jal toggle_pause                    # Turn pause menu off or on, depending on state
    j game_loop                         # Wait for next key press
    
quit_game:
    li $v0, 10                          # Terminate gracefully
    syscall

##############################################################################
# Start from menu: Transitions from Menu to Playing
##############################################################################
start_from_menu:
    sw $zero, game_state                # Update state to 0 (playing)
    
    jal clear_screen                    # Clear menu text
    
    # Initialize game board
    jal draw_playing_field
    jal generate_col                    # Create first set of gems
    
    # Draw initial gems
    lw $a0, curr_col_x
    lw $a1, curr_col_y
    la $t1, gem1_color
    jal draw_curr_col
    
    # Reset gravity so it doesn't drop immediately
    sw $zero, gravity_counter
    
    j handle_gravity                    # Skip first keyboard check

##############################################################################
# Toggle Pause: Handles switching between playing and paused (includes resume game)
#   $t0 - current state
#   $a0 = x coordinate
#   $a1 = y coordinate
#   $t1 = gem colours
##############################################################################
toggle_pause:
    addi $sp, $sp, -4                   # Move stack pointer
    sw $ra, 0($sp)                      # Store ra in stack

    lw $t0, game_state                  # Load in game state
    bne $t0, $zero, resume_game         # If game state is 1 (paused), resume

    # Handle when game gets paused
    li $t0, 1
    sw $t0, game_state                  # Update game state to 1 (paused)
    jal draw_pause_menu                 # Draw the paused menu
    j end_toggle                        # Return

resume_game:
    sw $zero, game_state                # Update game state to 0 (playing)
    
    # Clear entire screen (removes text box and text)
    jal clear_screen                    # Black out entire screen
    
    # Wipe the menu by redrawing everything
    jal draw_playing_field              # Redraw game board
    jal redraw_grid_contents            # Redraw all landed gems
    
    # Redraw active falling column
    lw $a0, curr_col_x                  # Load in current x
    lw $a1, curr_col_y                  # Load in current y
    la $t1, gem1_color                  # Get gem colors
    jal draw_curr_col                   # Draw

end_toggle:
    lw $ra, 0($sp)                      # Get ra from stack
    addi $sp, $sp, 4                    # Move stack pointer
    jr $ra                              # Return

##############################################################################
#                                                                            #
#                          DRAWING-RELATED CODE                              #
#                                                                            #
##############################################################################

##############################################################################
# Drawing the playing field
#   $a0 - The X coordinate for start of a vertical/horizontal line
#   $a1 - The Y coordinate for start of a vertical/horizontal line
#   $a2 - The color of the grid (all gray for boundaries)
#   $a3 - The length of the line being drawn (full width/height)
##############################################################################
draw_playing_field:
    addi $sp, $sp, -4                   # Preserve ra
    sw $ra, 0($sp)

    # Draw Top Wall
    lw $a0, grid_left                   # X start
    lw $a1, grid_top                    # Y start (Top of grid)
    lw $a2, grid_color                  # Color (Gray)
    lw $a3, grid_full_wid               # Full width
    jal draw_hor_line

    # Draw Bottom Wall
    lw $a0, grid_left                   # X start
    lw $a1, grid_bot                    # Y start (Bottom of grid)
    lw $a2, grid_color                  # Color
    lw $a3, grid_full_wid               # Full width
    jal draw_hor_line

    # Draw Left Wall
    lw $a0, grid_left                   # X start
    lw $a1, grid_top                    # Y start (Top of grid)
    lw $a2, grid_color                  # Color
    lw $a3, grid_full_hei               # Full height
    jal draw_ver_line

    # Draw Right Wall
    lw $a0, grid_right                  # X start (Right side)
    lw $a1, grid_top                    # Y start (Top of grid)
    lw $a2, grid_color                  # Color
    lw $a3, grid_full_hei               # Full height
    jal draw_ver_line

    lw $ra, 0($sp)                      # Restore ra
    addi $sp, $sp, 4
    jr $ra
    
##############################################################################
# Clear screen: Sets every pixel to black
#   $t0 = display base address
#   $t1 = color black
#   $t2 = pixel counter (1024 total)
##############################################################################
clear_screen:
    lw $t0, displayaddress
    li $t1, 0x000000                    # Black
    li $t2, 1024                        # 32 units * 32 units
    
clear_screen_loop:
    sw $t1, 0($t0)
    addi $t0, $t0, 4                    # Go to next pixel
    addi $t2, $t2, -1                   # Decrement number of pixels
    bnez $t2, clear_screen_loop         # Continue blacking out pixels
    jr $ra
    
##############################################################################
# Draw main menu: Paints "START" on the black screen
#   $s0 = X coordinate of top left corner of text
#   $s1 = Y coordinate of top left corner of text
#   $a2 = Color
##############################################################################
draw_main_menu:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $a2, text_color
    li $s0, 6                           # X Start
    li $s1, 14                          # Y Start (Middle of screen)

    # Draw "START"
    move $a0, $s0                       # S
    move $a1, $s1
    jal draw_letter_S
    
    addi $a0, $s0, 4                    # T
    move $a1, $s1
    jal draw_letter_T
    
    addi $a0, $s0, 8                    # A
    move $a1, $s1
    jal draw_letter_A
    
    addi $a0, $s0, 12                   # R
    move $a1, $s1
    jal draw_letter_R

    addi $a0, $s0, 16                   # T
    move $a1, $s1
    jal draw_letter_T

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Draw pause menu: Paints the rectangle and text
#   $a0 = X Coordinate
#   $a1 = Y Coordinate
#   $a2 = Color
#   $a3 = Width
#   $t5 = Height counter
##############################################################################
draw_pause_menu:
    addi $sp, $sp, -4                   # Move stack pointer
    sw $ra, 0($sp)                      # Store ra

    # Draw grey rectangle for text to go on
    lw $a2, text_box_color
    li $a0, 4                           # X coordinate of top left corner
    li $a1, 11                          # Y coordinate of top left corner
    li $a3, 25                          # Width of box
    li $t5, 9                           # Height of box
    
draw_box_loop:
    jal draw_hor_line                   # Draw horizontal line in grey
    addi $a1, $a1, 1
    addi $a0, $a0, -25                  # Reset X
    addi $t5, $t5, -1
    bgtz $t5, draw_box_loop

    lw $a2, text_color
    li $s0, 5                           # Fixed X starting point (top left)
    li $s1, 13                          # Fixed Y for all letters
    
    # "PAUSED"
    move $a0, $s0                       # P
    move $a1, $s1
    jal draw_letter_P
    
    addi $a0, $s0, 4                    # A
    move $a1, $s1   
    jal draw_letter_A
    
    addi $a0, $s0, 8                    # U
    move $a1, $s1                       
    jal draw_letter_U
    
    addi $a0, $s0, 12                   # S
    move $a1, $s1                       
    jal draw_letter_S
    
    addi $a0, $s0, 16                   # E
    move $a1, $s1
    jal draw_letter_E
    
    addi $a0, $s0, 20                   # D
    move $a1, $s1
    jal draw_letter_D

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
   
##############################################################################
# Draw game over menu: Paints the rectangle and text
#   $a0 = x coordinate of top left corner of box
#   $a1 = y coordinate of top left corner of box
#   $a2 = text/text box color (grey/white)
#   $a3 = width
#   $a5 = height counter
##############################################################################   
draw_game_over_menu:
    addi $sp, $sp, -4                   # Move stack pointer
    sw $ra, 0($sp)                      # Save ra

    # Draw grey background box
    lw $a2, text_box_color              # Initialize rectangular box color
    li $a0, 3                           # X coord. of top left corner
    li $a1, 5                           # Y coord. of top left corner
    li $a3, 26                          # Width
    li $t5, 24                          # Height

game_over_box_loop:
    jal draw_hor_line
    addi $a1, $a1, 1
    addi $a0, $a0, -26                  # Reset x
    addi $t5, $t5, -1                   # Decrement height counter
    bgtz $t5, game_over_box_loop

    lw $a2, text_color                  # Initialize text color
    li $s0, 6                           # Starting X offset for top left corner of "G"
    li $s1, 9                           # Starting Y offset for top left corner of "G"
    
    # "GAME"
    move $a0, $s0                       # G
    move $a1, $s1
    jal draw_letter_G
    
    addi $a0, $s0, 6                    # A
    move $a1, $s1
    jal draw_letter_A
    
    addi $a0, $s0, 10                   # M
    move $a1, $s1
    jal draw_letter_M
    
    addi $a0, $s0, 16                   # E
    move $a1, $s1
    jal draw_letter_E

    # "OVER"
    li $s0, 8                           # Starting X offset for top left corner of "O"
    li $s1, 15                          # Starting Y offset for top left corner of "O"

    move $a0, $s0                       # O
    move $a1, $s1
    jal draw_letter_O
    
    addi $a0, $s0, 4                    # V
    move $a1, $s1
    jal draw_letter_V
    
    addi $a0, $s0, 8                    # E
    move $a1, $s1
    jal draw_letter_E
    
    addi $a0, $s0, 12                   # R
    move $a1, $s1
    jal draw_letter_R

    # "(R)(Q)"
    li $s0, 5                           # Starting X offset for top left corner of "("
    li $s1, 21                          # Starting Y offset for top left corner of "("
    
    move $a0, $s0                       # (
    move $a1, $s1
    jal draw_parenthesis_left
    
    addi $a0, $s0, 3                    # R
    move $a1, $s1
    jal draw_letter_R
    
    addi $a0, $s0, 7                    # )
    move $a1, $s1
    jal draw_parenthesis_right
    
    addi $a0, $s0, 11                   # (
    move $a1, $s1
    jal draw_parenthesis_left
    
    addi $a0, $s0, 14                   # Q
    move $a1, $s1
    jal draw_letter_Q
    
    addi $a0, $s0, 20                   # )
    move $a1, $s1
    jal draw_parenthesis_right
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra    

##############################################################################
# Letter functions (3x5, 5x5 for G, M, Q)
#   $a0 = Top Left X of letter
#   $a1 = Top Left Y of letter
#   $a2 = Color
##############################################################################
draw_letter_P:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Left stem
    jal draw_pixel                      # Top-left stem (0, 0)
    addi $a1, $a1, 1                    # (0, -1)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -2)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -3)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -4)
    jal draw_pixel
    
    # Loop
    addi $a1, $a1, -4                   # Back to top (0, 0)
    addi $a0, $a0, 1                    # (1, 0)
    jal draw_pixel
    addi $a0, $a0, 1                    # (2, 0)
    jal draw_pixel
    addi $a1, $a1, 1                    # (2, -1)
    jal draw_pixel
    addi $a1, $a1, 1                    # (2, -2)
    jal draw_pixel
    addi $a0, $a0, -1                   # (1, -2)
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_A:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    addi $a1, $a1, 1                    # (0, -1), skip (0, 0)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -2)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -3)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -4)
    jal draw_pixel
    
    addi $a1, $a1, -4                   # Back to top row
    addi $a0, $a0, 1                    # (1, 0)
    jal draw_pixel
    addi $a1, $a1, 2                    # (1, -2)
    jal draw_pixel                      # Middle bar
    addi $a1, $a1, -2                   # Back to top row
    addi $a0, $a0, 1                    # (2, 0), skip draw
    addi $a1, $a1, 1                    # (2, -1)
    jal draw_pixel                      
    addi $a1, $a1, 1                    # (2, -2)
    jal draw_pixel
    addi $a1, $a1, 1                    # (2, -3)
    jal draw_pixel
    addi $a1, $a1, 1                    # (2, -4)
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Too lazy to annotate
draw_letter_U:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_S:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, -2
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a0, $a0, -1
    jal draw_pixel
    addi $a0, $a0, -1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_E:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    addi $a1, $a1, -4                 
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    
    addi $a0, $a0, -1                  
    addi $a1, $a1, 2
    jal draw_pixel
    
    addi $a1, $a1, 2                    
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_D:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel                  
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    addi $a1, $a1, -4                  
    addi $a0, $a0, 1
    jal draw_pixel
    
    addi $a1, $a1, 4                
    jal draw_pixel
    
    addi $a0, $a0, 1
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
draw_letter_T:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_pixel                     
    addi $a0, $a0, 1
    jal draw_pixel                     
    addi $a0, $a0, 1
    jal draw_pixel                    
    addi $a0, $a0, -1             
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_R:
    addi $sp, $sp, -12              
    sw $ra, 8($sp)
    sw $s0, 4($sp)                      # Save original X
    sw $s1, 0($sp)                      # Save original Y
    
    move $s0, $a0                    
    move $s1, $a1                      
    
    jal draw_pixel                   
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel                      
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    move $a0, $s0
    move $a1, $s1
    addi $a0, $a0, 1                    
    jal draw_pixel                      
    addi $a1, $a1, 2                    
    jal draw_pixel                      
    move $a0, $s0
    move $a1, $s1
    addi $a0, $a0, 2                    
    jal draw_pixel                      
    addi $a1, $a1, 1
    jal draw_pixel                      
    addi $a1, $a1, 1
    jal draw_pixel                      
    move $a0, $s0
    move $a1, $s1
    addi $a0, $a0, 1        
    addi $a1, $a1, 3        
    jal draw_pixel
    addi $a0, $a0, 1        
    addi $a1, $a1, 1        
    jal draw_pixel

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

draw_letter_G:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)                      # Save original X
    sw $s1, 0($sp)                      # Save original Y
    
    move $s0, $a0                
    move $s1, $a1                    

    addi $a0, $s0, 1                    # (1, 0) skip (0, 0)
    jal draw_pixel         
    addi $a0, $a0, 1                    # (2, 0)
    jal draw_pixel                  
    addi $a0, $a0, 1                    # (3, 0)
    jal draw_pixel           

    move $a0, $s0                       # (0, 0)   
    addi $a1, $s1, 1                    # (0, -1)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -2)
    jal draw_pixel
    addi $a1, $a1, 1                    # (0, -3)
    jal draw_pixel
    
    addi $a1, $a1, 1                    # (0, -4)
    addi $a0, $s0, 1                    # (1, -4)
    jal draw_pixel
    addi $a0, $a0, 1                    # (2, -4)
    jal draw_pixel
    addi $a0, $a0, 1                    # (3, -4)
    jal draw_pixel
    addi $a0, $a0, 1                    # (4, -4)
    jal draw_pixel
    
    move $a0, $s0                       # (0, -4)
    move $a1, $s1                       # (0, 0)
    addi $a0, $a0, 4                    # (4, 0)
    addi $a1, $a1, 4                    # (4, -4)
    jal draw_pixel
    addi $a1, $a1, -1                   # (4, -3)
    jal draw_pixel
    addi $a1, $a1, -1                   # (4, -2)
    jal draw_pixel
    
    addi $a0, $a0, -1                   # (3, -2)
    jal draw_pixel     
    addi $a0, $a0, -1                   # (2, -2)
    jal draw_pixel     

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
draw_letter_M:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    addi $a1, $a1, -4
    addi $a0, $a0, 1
    jal draw_pixel                      
    addi $a0, $a0, 1
    jal draw_pixel                      
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    addi $a1, $a1, -4
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_O:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel                    
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, -4
    addi $a0, $a0, 1
    jal draw_pixel            
    addi $a1, $a1, 4
    jal draw_pixel                   
    addi $a0, $a0, 1
    addi $a1, $a1, -4
    jal draw_pixel                 
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_V:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel                      
    addi $a1, $a1, 1
    addi $a0, $a0, 1
    jal draw_pixel                      
    addi $a1, $a1, -1
    addi $a0, $a0, 1
    jal draw_pixel                      
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    addi $a1, $a1, -1
    jal draw_pixel
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_letter_Q:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    move $s0, $a0           
    move $s1, $a1           

    addi $a0, $s0, 1    
    jal draw_pixel          
    addi $a1, $s1, 4
    jal draw_pixel          
    addi $a0, $s0, 2
    move $a1, $s1
    jal draw_pixel  
    addi $a1, $s1, 4
    jal draw_pixel
    addi $a0, $s0, 3
    move $a1, $s1
    jal draw_pixel

    move $a0, $s0
    addi $a1, $s1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel

    addi $a0, $s0, 4
    move $a1, $s1
    addi $a1, $a1, 1
    jal draw_pixel  
    addi $a1, $a1, 1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel

    addi $a0, $s0, 3
    addi $a1, $s1, 3
    jal draw_pixel          
    addi $a0, $s0, 4
    addi $a1, $s1, 4
    jal draw_pixel

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
draw_parenthesis_left:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    move $s0, $a0
    move $s1, $a1

    addi $a0, $s0, 1  
    move $a1, $s1           
    jal draw_pixel
    addi $a1, $s1, 4        
    jal draw_pixel

    move $a0, $s0           
    addi $a1, $s1, 1       
    jal draw_pixel
    addi $a1, $a1, 1       
    jal draw_pixel
    addi $a1, $a1, 1       
    jal draw_pixel

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
draw_parenthesis_right:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    move $s0, $a0
    move $s1, $a1

    move $a0, $s0           
    move $a1, $s1           
    jal draw_pixel
    addi $a1, $s1, 4       
    jal draw_pixel

    addi $a0, $s0, 1        
    addi $a1, $s1, 1        
    jal draw_pixel
    addi $a1, $a1, 1        
    jal draw_pixel
    addi $a1, $a1, 1        
    jal draw_pixel

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra
    
##############################################################################
# Drawing a horizontal line
#   $a0 = The X coordinate of the start of the line
#   $a1 = The Y coordinate of the start of the line
#   $a2 = The color of the line
#   $a3 = The length of the horizontal line
#   $t0 = Location of the top-left corner of the bitmap
#   $t1 = The index counter for tracking line length
##############################################################################
draw_hor_line:
    addi $sp, $sp, -4                   # Save ra
    sw $ra, 0($sp)                      # Load ra onto the stack
    add $t1, $zero, $zero               # Initialize the index counter at 0

# Loop through the line & draw pixels one by one
hor_line_loop:
    beq $t1, $a3, end_hor_loop          # End loop if index counter increments to length
    jal draw_pixel                      # Draw the pixel at the current location
    addi $a0, $a0, 1                    # Move the X coordinates right for 1 row
    addi $t1, $t1, 1                    # Increment the counter
    j hor_line_loop                     # Repeat the process

end_hor_loop:
    lw $ra, 0($sp)                      # Restore the ra
    addi $sp, $sp, 4  
    jr $ra

##############################################################################
# Drawing a vertical line
#   $a0 = The X coordinate of the start of the line
#   $a1 = The Y coordinate of the start of the line
#   $a2 = The color of the line
#   $a3 = The length of the vertical line
#   $t0 = Location of the top-left corner of the bitmap
#   $t1 = The index counter for tracking line length
##############################################################################
draw_ver_line:
    addi $sp, $sp, -4                   # Save ra
    sw $ra, 0($sp)                      # Load ra onto the stack
    add $t1, $zero, $zero               # Initialize the index counter to 0

# Loop through the line & draw pixels one by one
ver_line_loop:
    beq $t1, $a3, end_ver_loop          # End loop if index counter increments to length
    jal draw_pixel                      # Draw the pixel at the current location
    addi $a1, $a1, 1                    # Move the coordinates down for 1 row
    addi $t1, $t1, 1                    # Increment the counter              
    j ver_line_loop                     # Repeat the process

end_ver_loop:
    lw $ra, 0($sp)                      # Restore the ra
    addi $sp, $sp, 4  
    jr $ra
    
##############################################################################
# Drawing a single pixel
#   $a0 = The X coordinate of the pixel
#   $a1 = The Y coordinate of the pixel
#   $a2 = The color of the gem
#   $t0 = display address
#   $t8 = X offset
#   $t9 = Y offset
##############################################################################
draw_pixel:
    # Paint the pixel in corresponding location
    sll $t8, $a0, 2                     # Calculate the bitmap location based on X (times 4)
    sll $t9, $a1, 7                     # Calculate the bitmap location based on Y (times 128)

    lw $t0, displayaddress              # load the diplay address
    addu $t0, $t0, $t8                  # Add X offset
    addu $t0, $t0, $t9                  # Add Y offset
    sw $a2, 0($t0)                      # Paint the pixel with color in $a2

    jr $ra                              # End of function
    
##############################################################################
# Generate a 3-gem column with random colors in memory (no display)
#   $a0 = Index pointing to a color (random selection)
#   $t1 = Index counter for number of gems
#   $t2 = Store memory address of the gems (starting with 1st)
#   $t3 = Color address for each gem (based on random selection)
#   $t4 = Storage of actual color
#   $t5 = Number of gems drawn
##############################################################################
generate_col:
    addi $sp, $sp, -4                   # Preserve ra
    sw $ra, 0($sp)                      # Load ra onto the stack
    li $t1, 0                           # Initialize gem counter
    li $t5, 3                           # Load the total number of gems (3)
    la $t2, gem1_color                  # Point to the memory address of the 1st gem

# Loop through 3 gems & generate random colors for each
generate_col_loop:
    beq $t1, $t5, end_generate_col_loop # Break loop if all 3 gem colors have been initiated
    li $v0, 42                          # Random generation
    li $a0, 0                           # Set range from 0-5 (corresponding to six colors)
    li $a1, 6
    syscall                             # Store the random selected index in $a0
    
    sll $a0, $a0, 2                     # Get color's address in memory (index * 4 bytes)
    la $t3, palette                     # Point to the start of the palette
    addu $t3, $t3, $a0                  # Based on the address, get the corresponding color
    lw $t4, 0($t3)                      # Load the value of the color
    sw $t4, 0($t2)                      # Store the color in the memory (gem_color_i)
    
    addi $t2, $t2, 4                    # Move to the next gem
    addi $t1, $t1, 1                    # Increment index counter
    j generate_col_loop

end_generate_col_loop:
    lw $ra, 0($sp)                      # Restore the ra
    addi $sp, $sp, 4  
    jr $ra

##############################################################################
# Drawing the current column
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $a2 = Current gem's color
#   $t1 = Starting point of address of generated gem colors
#   $t2 = Index counter
#   $t3 = Number of gems
#   $t4 = Temporary safety storage for $a0
#   $t5 = Temporary safety storage for $a1
##############################################################################
draw_curr_col:
    addi $sp, $sp, -4                   # Preserve ra
    sw $ra, 0($sp)                      # Load ra onto the stack
    
    li $t2, 0                           # Initialize counter
    li $t3, 3                           # Initialize number of gems

draw_curr_col_loop:
    beq $t2, $t3, end_draw_curr_col_loop    # End loop when all 3 gems have been painted
    
    move $t4, $a0                       # Temporarily save $a0 just in case
    move $t5, $a1                       # Similarly for $a1
    lw $a2, 0($t1)                      # Load the color of the current gem
    jal draw_pixel                      # Draw the pixel at corresponding location
    move $a0, $t4                       # Restore the values
    move $a1, $t5
    
    addi $a1, $a1, 1                    # Move to next gem (increment Y)
    addi $t1, $t1, 4                    # Move to next gem color address in memory
    addi $t2, $t2, 1                    # Increment counter
    j draw_curr_col_loop
    
end_draw_curr_col_loop:
    lw $ra, 0($sp)                      # Restore ra
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Redraw Grid Contents: Restores the board after the menu disappears
#   $s0 = X counter
#   $s1 = Y counter
#   $v0 = Color returned from memory
##############################################################################
redraw_grid_contents:
    addi $sp, $sp, -12                  # Move stack pointer
    sw $ra, 8($sp)                      # Store ra
    sw $s0, 4($sp)                      # Store x
    sw $s1, 0($sp)                      # Store y

    li $s1, 0                           # Initialize y counter
    
row_redraw:
    li $s0, 0                           # Initialize x counter
    
col_redraw:
    # Convert grid index to bitmap coordinates
    addi $a0, $s0, 5                
    addi $a1, $s1, 5
    jal get_grid_value                  # Check grid memory
    move $a2, $v0                       # Get color
    beq $a2, $zero, skip_redraw_pixel   # If empty, don't draw
    jal draw_pixel                      # Draw gem

skip_redraw_pixel:
    addi $s0, $s0, 1                    # Increment x counter
    li $t7, 11                          # Grid width
    blt $s0, $t7, col_redraw            # Check if you're at the end of the row
    
    addi $s1, $s1, 1                    # Increment y counter
    li $t7, 20                          # Grid height
    blt $s1, $t7, row_redraw

    # Restore values from stack
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra    

##############################################################################
# Move down by one pixel (gravity functionality)
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $t1 = Current color of the gems
#   $t2 = Placeholder for updating new gem position in memory
#   $t3 = Position of left grid wall
##############################################################################
move_down:
    # Save ra: returns to run_gravity
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Boundary check    
    lw $a0, curr_col_x
    lw $a1, curr_col_y
    addi $a1, $a1, 3                    # Check row under bottom gem
    
    # Check if gem hits floor
    lw $t3, grid_bot                    # Load in value of bottom of grid
    bge $a1, $t3, land_gem              # If bottom gem hits floor, run collision logic
    
    # Check if other gem was hit
    jal get_grid_value
    bne $v0, $zero, land_gem            # If color isn't 0, there's a gem
    
    # Erase column in old position
    lw $a0, curr_col_x                  # Get the current positions of topmost gem
    lw $a1, curr_col_y
    la $t1, black_palette               # Get the black palette for painting
    jal draw_curr_col                   # Erase the old column (repaint with black)
    
    # Update position (Y coordinate)
    lw $t0, curr_col_y                  # Load in current y position of bottom gem
    addi $t0, $t0, 1                    # Increment
    sw $t0, curr_col_y                  # Save updated y coordinate
    
    # Draw the (same) column in new position
    lw $a0, curr_col_x                  # Load in the new coordinates
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the gem palette for normal drawing
    jal draw_curr_col
    
    j end_move_down
    
land_gem:
    jal handle_collision
    
end_move_down:
    lw $ra, 0($sp)                      # Fetch ra from stack
    addi $sp, $sp, 4                    # Move stack pointer
    jr $ra                              # Return to run_gravity
    
##############################################################################
# Move left by one pixel (when "A" is pressed)
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $t1 = Current color of the gems
#   $t2 = Placeholder for updating new gem position in memory
#   $t3 = Position of left grid wall
##############################################################################
move_left:
    # Boundary check
    lw $t2, curr_col_x                  # Load current position
    lw $t3, grid_left                   # Load left wall position
    addi $t3, $t3, 1                    # The first playable position within the field
    beq $t2, $t3, game_loop             # If the column is already at edge, go back to loop (no update)
    
    # Check if column to the left has blocks
    lw $a0, curr_col_x                  # Load in x
    addi $a0, $a0, -1                   # Subtract 1 to check column to left
    lw $s7, curr_col_y                  # Store y to check
    
    # Check bottom gem
    addi $a1, $s7, 2                    # Add 2 to topmost gem y to get bottom
    jal get_grid_value
    bne $v0, $zero, game_loop           # Check if grid next to gem is colored
    
    # Erase the column in old position
    lw $a0, curr_col_x                  # Get the current positions of topmost gem
    lw $a1, curr_col_y
    la $t1, black_palette               # Get the black palette for painting
    jal draw_curr_col                   # Erase the old column (repaint with black)
    
    # Update position (X coordinate)
    lw $t2, curr_col_x                  # Load the current column position
    addi $t2, $t2, -1                   # Move left by 1
    sw $t2, curr_col_x                  # Renew the updated X coordinate in memory
    
    # Draw the (same) column in new position
    lw $a0, curr_col_x                  # Load in the new coordinates
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the gem palette for normal drawing
    jal draw_curr_col
    
    j game_loop                         # Move back to the game loop for next check
    
##############################################################################
# Move right by one pixel (when "D" is pressed)
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $t1 = Current color of the gems
#   $t2 = Placeholder for updating new gem position in memory
#   $t3 = Position of left grid wall
##############################################################################
move_right:
    # Boundary check
    lw $t2, curr_col_x                  # Load current position
    lw $t3, grid_right                  # Load right wall position
    addi $t3, $t3, -1                   # The first playable position within the field
    beq $t2, $t3, game_loop             # If the column is already at edge, go back to loop (no update)
    
    # Check if column to the right has blocks
    lw $a0, curr_col_x                  # Load in x
    addi $a0, $a0, 1                    # Add 1 to check column to right
    lw $s7, curr_col_y                  # Store y to check
    
    # Check bottom gem
    addi $a1, $s7, 2                    # Add 2 to topmost gem y to get bottom
    jal get_grid_value
    bne $v0, $zero, game_loop           # Check if grid next to gem is colored
    
    # Erase the column in old position
    lw $a0, curr_col_x                  # Get the current positions of topmost gem
    lw $a1, curr_col_y
    la $t1, black_palette               # Get the black palette for painting
    jal draw_curr_col                   # Erase the old column (repaint with black)
    
    # Update position (X coordinate)
    lw $t2, curr_col_x                  # Load the current column position
    addi $t2, $t2, 1                    # Move right by 1
    sw $t2, curr_col_x                  # Renew the updated X coordinate in memory
    
    # Draw the (same) column in new position
    lw $a0, curr_col_x                  # Load in the new coordinates
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the gem palette for normal drawing
    jal draw_curr_col
    
    j game_loop                         # Move back to the game loop for next check

##############################################################################
# Dropping a column to the bottom at once when "S" is pressed
#   $s0 = (Safety storage) Current X coordinate of column (topmost gem)
#   $s1 = (Safety storage) Current Y coordinate of column (topmost gem)
#   $s4 = Checker for whether any gems are deleted
#   $a0 = Holder for X coordinate of column (topmost gem)
#   $a1 = Holder for Y coordinate of column (topmost gem)
#   $t0 = Holder for conditions of game over (5) and generate new column (respawn)
#   $t1 = Current color of the gems
#   $t2 = Y coordinates for bottom-most gem
#   $t3 = Holder of value for bottom of playing field
##############################################################################
drop_at_once:
    lw $s0, curr_col_x                  # Initialize mutable coordinates for checking
    lw $s1, curr_col_y                  # Y coordinate is responsible for checking "bottom"    

drop_loop:
    addi $s1, $s1, 1                    # Move Y checker down by 1
    
    # Boundary check for reaching playing field bottom
    addi $t2, $s1, 2                    # Y coordinates for the bottom-most gem
    lw $t3, grid_bot                    # Load the bottom of the playing field
    addi $t3, $t3, -1                    # Move bottom up by 1
    bgt $t2, $t3, collision_final       # The bottom is hit (i.e., gem moves past playable area)
    
    # Collision check for reaching an existing gem
    move $a0, $s0                       # Retrieve the curr_x coordinates
    move $a1, $t2                       # Retrieve Y coordinates for bottom gem
    jal get_grid_value                  # Check for values in current position
    bne $v0, $zero, collision_final     # If the value is not 0, the grid is occupied
    
    j drop_loop                         # Keep moving down

collision_final:
    addi $s1, $s1, -1                   # Move to last safe y position

    # Erase the column in old position
    lw $a0, curr_col_x                  # Get the current positions of topmost gem
    lw $a1, curr_col_y
    la $t1, black_palette               # Get the black palette for painting
    jal draw_curr_col                   # Erase the old column (repaint with black)
    
    sw $s1, curr_col_y                  # Update to new y position
    
    # Draw the (same) column in new position
    lw $a0, curr_col_x                  # Load in the new coordinates
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the gem palette for normal drawing
    jal draw_curr_col
    
    # Trigger the shared collision handler (with gravity)
    jal handle_collision
    j game_loop

##############################################################################
# Shuffle the columns when "W" is pressed (top->mid, mid->bot, bot->top)
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $t0 = Color of top gem
#   $t1 = Color of middle gem
#   $t2 = Color of bottom gem
##############################################################################
shuffle_col:
    # Load current colors of the column
    lw $t0, gem1_color                  # top
    lw $t1, gem2_color                  # mid
    lw $t2, gem3_color                  # bot
    
    # Swap the colors in order
    sw $t2, gem1_color                  # bot->top
    sw $t0, gem2_color                  # top->mid
    sw $t1, gem3_color                  # mid->bot
    
    # Redraw the column at same position with shuffled colors
    lw $a0, curr_col_x
    lw $a1, curr_col_y
    la $t1, gem1_color                  # The new gem color order
    jal draw_curr_col
    
    # TO BE CHANGED: Redraw the displayed column (on the side) if we decide to display current col
    # IGNORE if display/preview next col (no need to update with shuffle)
    
    j game_loop                         # Return to the game loop for next input

##############################################################################
# Check if a grid within the playing field is occupied
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $v0 = Value of grid being checked (returns color, or 0 if empty)
#   $v1 = Address of grid being checked
#   $t0 = Holder of width of playing field & initial address of grid
#   $t1 = Index of (X, Y) coordinate in memory
#   $t8 = Relative position of X in the memory of playing field (0-10)
#   $t9 = Relative position of Y in the memory of playing field (0-19)
##############################################################################
get_grid_value:
    # Translate the current (X, Y) coordinates to memory address
    addi $t8, $a0, -5                   # Reset the X, Y offset to 0 (for memory)
    addi $t9, $a1, -5
    
    # Calculate the index of the current coordinate in memory
    lw $t0, grid_width                  # Load the width of the playing field (currently 11)
    mult $t9, $t0                       # Skip over the previous rows
    mflo $t1                            # Update the Y coordinate in memory (get the current row)
    add $t1, $t1, $t8                   # Add to the current X coordinate (get the current column)
    sll $t1, $t1, 2                     # Convert index into bytes (direct access to memory)
    
    la $t0, grid                        # Load the starting point of grid memory
    add $t1, $t0, $t1                   # Move to the current point (the real address)
    lw $v0, 0($t1)                      # Load the value (color) in that grid to $v0
    move $v1, $t1                       # Return the address of the current grid
    
    jr $ra                              # Exit the function

##############################################################################
# Collision checking
#   $s0 = (Safety storage) Current X coordinate of column (topmost gem)
#   $s1 = (Safety storage) Current Y coordinate of column (topmost gem)
#   $s4 = Checker for whether any gems are deleted
#   $a0 = Holder for X coordinate of column (topmost gem)
#   $a1 = Holder for Y coordinate of column (topmost gem)
#   $t0 = Holder for conditions of game over (5) and generate new column (respawn)
#   $t1 = Current color of the gems
#   $t2 = Y coordinates for bottom-most gem
#   $t3 = Holder of value for bottom of playing field
##############################################################################
# Perform the repainting of collision
collision:
    # Erase the previous position
    addi $s1, $s1, -1                   # Move up by 1
    lw $a0, curr_col_x                  # Load column positions
    lw $a1, curr_col_y
    la $t1, black_palette               # Color them black
    jal draw_curr_col
    sw $s1, curr_col_y                  # Renew the curr_col position
    
    # Draw at the new unoccupied area
    lw $a0, curr_col_x                  # Load the inputs
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Load the colors of the gems
    jal draw_curr_col
    
    # Lock the column in position & store in grid memory
    jal lock_curr_col

##############################################################################
# Chain reaction for checking & deleting matches
#   $s0 = (Safety storage) Current X coordinate of column (topmost gem)
#   $s1 = (Safety storage) Current Y coordinate of column (topmost gem)
#   $s4 = Checker for whether any gems are deleted
#   $a0 = Holder for X coordinate of column (topmost gem)
#   $a1 = Holder for Y coordinate of column (topmost gem)
#   $t0 = Holder for conditions of game over (5) and generate new column (respawn)
#   $t1 = Current color of the gems
#   $t2 = Y coordinates for bottom-most gem
#   $t3 = Holder of value for bottom of playing field
##############################################################################
# Handles collision when gravity causes column to collide with bottom
handle_collision:
    # Save ra to stack
    addi $sp, $sp, -4                   # Move stack pointer
    sw $ra, 0($sp)                      # Save ra
    
    jal lock_curr_col

chain_reaction_loop:
    # Check 3-in-a-row in conditions: vertical, horizontal, diagonal
    jal check_vertical_matches
    jal check_horizontal_matches
    jal check_down_left_matches
    jal check_down_right_matches
    
    # Apply deletions
    jal delete_match
    move $s4, $v0
    beq $s4, $zero, end_collision      # Stop chain reaction if nothing continues to be deleted
    
    # Drop any hovering gems
    jal collapse_columns
    
    j chain_reaction_loop               # Continue checking for new matches
    
end_collision:
    # Check for Game Over condition (column hits top)
    jal check_game_end
    
    # Re-initialze coordinates for next piece if game continues
    jal respawn
    jal generate_col                    # Generate new column at initial position
    
    # Draw new column
    lw $a0, curr_col_x                  # Load the initialized position     
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the new gem color
    jal draw_curr_col                   # Draw the new column in playing field 
    
    # Restore ra
    lw $ra, 0($sp)
    addi $sp, $sp, 4                   # Pop one-by-one in reverse
        
    jr $ra                             # Return to ra
    
##############################################################################
# Lock current column in place & store it in grid memory
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $v1 = Address of current gem (returned by get_grid_value)
#   $t0 = Color of current gem
##############################################################################
lock_curr_col:
    addi $sp, $sp, -4                   # Preserve current ra
    sw $ra, 0($sp)
    
    # Lock & store gem 1
    lw $a0, curr_col_x                  # Load the position of topmost gem
    lw $a1, curr_col_y
    jal get_grid_value                  # Get the address of the curent gem
    lw $t0, gem1_color                  # Get the color of the gem
    sw $t0, 0($v1)                      # Store the color of current gem into grid memory
    
    # Lock & store gem 2
    lw $a0, curr_col_x                  # Load the position of topmost gem
    lw $a1, curr_col_y
    addi $a1, $a1, 1                    # Move 1 row down for middle gem
    jal get_grid_value                  # Get address
    lw $t0, gem2_color                  # Color of middle gem
    sw $t0, 0($v1)                      # Store color into grid memory
    
    # Lock & store gem 3
    lw $a0, curr_col_x                  # Load the position of topmost gem
    lw $a1, curr_col_y
    addi $a1, $a1, 2                    # Move 2 rows down for bottom gem
    jal get_grid_value                  # Get address
    lw $t0, gem3_color                  # Color of bottom gem
    sw $t0, 0($v1)                      # Store color into grid memory
    
    lw $ra, 0($sp)                      # Restore ra
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Check if the game has ended
#   $t0 = Holder for end condition values (edge of playable area)
#   $t1 = Current Y coordinate of column (topmost gem)
##############################################################################
check_game_end:
    li $t0, 5                           # Load $t0 with the highest playable area (1 row under ceiling)
    lw $t1, curr_col_y                  # Check the position of current column
    ble $t1, $t0, trigger_game_over     # If column is higher than playable area, it has reached the ceiling
    jr $ra
    
trigger_game_over:
    li $t0, 3
    sw $t0, game_state                  # Switch to Game Over state
    jal draw_game_over_menu             # Draw game over message
    j game_loop                         # Return to loop to wait for 'R' (restart signal)

##############################################################################
# Restart game: Wipes memory and starts a new game
##############################################################################
restart_game:
    jal reset_grid_memory               # Erase everything in the game grid
    jal respawn                         # Reset column x and y
    j start_from_menu                   # Use existing logic to clear screen and draw grid

##############################################################################
# Reset grid memory: Reset everything in the game grid to 0
#   $t0 = grid
#   $t1 = grid value to fill in for reset
#   $t2 = counter (for number of grid slots to fill)
##############################################################################
reset_grid_memory:
    la $t0, grid                        # Load in grid
    li $t1, 0                           # Load in grid value
    li $t2, 220                         # Load in counter

reset_grid_loop:
    sw $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bnez $t2, reset_grid_loop
    jr $ra

##############################################################################
# Respawn: Restore X and Y coordinates to initial position
#   $t0 = Current x and y (repurposed)
##############################################################################
respawn:
    li $t0, 10                          # Initial X offset
    sw $t0, curr_col_x                  # Re-initialize current X coordinates
    li $t0, 5                           # Initial Y offset
    sw $t0, curr_col_y                  # Re-initialize Y
    jr $ra

##############################################################################
# Check vertical matches: perform scan on any vertical 3-in-a-row gems
#   $s0 = Color of current gem
#   $s1 = Color of second gem (one row down)
#   $s2 = Color of third gem (two rows down)
#   $t0 = Holder for width of playing field (11)
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Marker for match (marking 1 in match_grid for gems that needs deletion)
#   $t4 = Holder for height - 2 of playing field (18)
#   $t5 = Holder of memory of playable grid & temporary grid
#   $t8 = Counter for the rows/Y coordinates (looping from 0-17, for Y+2)
#   $t9 = Counter for the columns/X coordinates (0-10)
##############################################################################
check_vertical_matches:
    addi $sp, $sp, -16                  # Preserve ra & colors in s0-2 (prevents override in collision)
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    
    li $t8, 0                           # Initialize the row counter
    li $t4, 18                          # Load the height - 2
    
# Loop over the rows of the playing field
vertical_row_loop:
    li $t9, 0                           # Initialize the column index counter

# Loop through the grid of each row
vertical_col_loop:
    # Calculate the index of current gem in memory
    lw $t0, grid_width                  # Load width of playing field
    mult $t8, $t0                       # Address for start of current row         
    mflo $t1
    add $t1, $t1, $t9                   # Add the column offset
    sll $t1, $t1, 2                     # Multiply by 4 to get index in memory
    
    # Load the colors
    la $t5, grid                        # Load the memory of the grid
    add $t2, $t5, $t1                   # Get the address of the current gem
    lw $s0, 0($t2)                      # Load the 1st gem's color
    lw $s1, 44($t2)                     # Load 2nd gem's color (4 bytes + number of pixels per row)
    lw $s2, 88($t2)                     # Load 3rd gem's color
    
    # Check for matches
    beq $s0, $zero, vertical_next_col   # Check if current grid is empty (if so, no match)
    bne $s0, $s1, vertical_next_col     # Check if the second gem has same color (if not, move to next loop)
    bne $s0, $s2, vertical_next_col     # Check the third gem
    
    # If all checks passed: Vertical 3-in-a-row -> Mark the match_grid for deletion
    la $t5, match_grid                   # Load the temporary grid
    add $t2, $t5, $t1                   # Similarly, get address for current gem
    li $t3, 1                           # Load the marker
    sw $t3, 0($t2)                      # Mark the gems as 1 for deletion afterwards
    sw $t3, 44($t2)
    sw $t3, 88($t2)
    
# Skip to the next column (grid on a row)
vertical_next_col:
    addi $t9, $t9, 1                    # Increment column counter
    blt $t9, $t0, vertical_col_loop     # Continue loop if boundary hasn't been reached
    
    addi $t8, $t8, 1                    # Increment row counter (next row)
    blt $t8, $t4, vertical_row_loop     # Continue loop if boundary hasn't been reached
    
    lw $s2, 0($sp)                      # Restore ra & pop color values
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16                        
    jr $ra

##############################################################################
# Check horizontal matches: perform a horizontal scan on any horizontal 3-in-a-row gems
#   $s0 = Color of current gem
#   $s1 = Color of second gem (one row down)
#   $s2 = Color of third gem (two rows down)
#   $t0 = Holder for width of playing field (11)
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Marker for match (marking 1 in match_grid for gems that needs deletion)
#   $t4 = Holder for width - 2 of playing field (9)
#   $t5 = Holder of memory of playable grid & temporary grid
#   $t6 = Holder for height of the playing field (20)
#   $t8 = Counter for the rows/Y coordinates (looping from 0-17, for Y+2)
#   $t9 = Counter for the columns/X coordinates (0-10)
##############################################################################
check_horizontal_matches:
    addi $sp, $sp, -16                  # Preserve ra & colors in s0-2 (prevents override in collision)
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    
    li $t8, 0                           # Initialize the row counter
    li $t4, 9                           # Load the width - 2
    lw $t6, grid_height                 # Load the height of playing field (20)
    
# Loop over the rows of the playing field
horizontal_row_loop:
    li $t9, 0                           # Initialize the column index counter
    
# Loop through the grid of each row
horizontal_col_loop:
    # Calculate the index of current gem in memory
    lw $t0, grid_width                  # Load width of playing field
    mult $t8, $t0                       # Address for start of current row         
    mflo $t1
    add $t1, $t1, $t9                   # Add the column offset
    sll $t1, $t1, 2                     # Multiply by 4 to get index in memory
        
    # Load the colors
    la $t5, grid                        # Load the memory of the grid
    add $t2, $t5, $t1                   # Get the address of the current gem
    lw $s0, 0($t2)                      # Load the 1st gem's color
    lw $s1, 4($t2)                      # Load 2nd gem's color (+ 4 bytes)
    lw $s2, 8($t2)                      # Load 3rd gem's color
    
    # Check for matches
    beq $s0, $zero, horizontal_next_col       # Check if current grid is empty (if so, no match)
    bne $s0, $s1, horizontal_next_col         # Check if the second gem has same color (if not, move to next loop)
    bne $s0, $s2, horizontal_next_col         # Check the third gem
    
    # If all checks passed: Horizontal 3-in-a-row -> Mark the match_grid for deletion
    la $t5, match_grid                  # Load the temporary grid
    add $t2, $t5, $t1                   # Similarly, get address for current gem
    li $t3, 1                           # Load the marker
    sw $t3, 0($t2)                      # Mark the gems as 1 for deletion afterwards
    sw $t3, 4($t2)
    sw $t3, 8($t2)

# Skip to the next column (grid on a row)
horizontal_next_col:
    addi $t9, $t9, 1                    # Increment column counter
    blt $t9, $t4, horizontal_col_loop   # Continue loop if boundary hasn't been reached
    
    addi $t8, $t8, 1                    # Increment row counter (next row)
    blt $t8, $t6, horizontal_row_loop   # Continue loop if boundary hasn't been reached
    
    lw $s2, 0($sp)                      # Restore ra & pop color values
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16                        
    jr $ra

##############################################################################
# Check diagonal down left: perform a diagonal down_left scan on any diagonal 3-in-a-row gems
#   $s0 = Color of current gem
#   $s1 = Color of second gem (one row down)
#   $s2 = Color of third gem (two rows down)
#   $t0 = Holder for width of playing field (11)
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Marker for match (marking 1 in match_grid for gems that needs deletion)
#   $t4 = Holder for width of playing field (11)
#   $t5 = Holder of memory of playable grid & temporary grid
#   $t6 = Holder for height - 2 of the playing field (20)
#   $t8 = Counter for the rows/Y coordinates (looping from 0-17, for Y+2)
#   $t9 = Counter for the columns/X coordinates (2-10)
##############################################################################
check_down_left_matches:
    addi $sp, $sp, -16                  # Preserve ra & colors in s0-2 (prevents override in collision)
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    
    li $t8, 0                           # Initialize the row counter
    li $t4, 11                          # Load the width
    li $t6, 18                          # Load the height of playing field
    
# Loop over the rows of the playing field
down_left_row_loop:
    li $t9, 2                           # Initialize the column index counter
    
# Loop through the grid of each row
down_left_col_loop:
    # Calculate the index of current gem in memory
    lw $t0, grid_width                  # Load width of playing field
    mult $t8, $t0                       # Address for start of current row         
    mflo $t1
    add $t1, $t1, $t9                   # Add the column offset
    sll $t1, $t1, 2                     # Multiply by 4 to get index in memory
    
    # Load the colors
    la $t5, grid                        # Load the memory of the grid
    add $t2, $t5, $t1                   # Get the address of the current gem
    lw $s0, 0($t2)                      # Load the 1st gem's color
    lw $s1, 40($t2)                     # Load 2nd gem's color (Down 1 & Left 1: 44 - 4)
    lw $s2, 80($t2)                     # Load 3rd gem's color (Down 2 & Left 2: 88 - 8)
    
    # Check for matches
    beq $s0, $zero, down_left_next_col       # Check if current grid is empty (if so, no match)
    bne $s0, $s1, down_left_next_col         # Check if the second gem has same color (if not, move to next loop)
    bne $s0, $s2, down_left_next_col         # Check the third gem
    
    # If all checks passed: Diagonal 3-in-a-row -> Mark the match_grid for deletion
    la $t5, match_grid                  # Load the temporary grid
    add $t2, $t5, $t1                   # Similarly, get address for current gem
    li $t3, 1                           # Load the marker
    sw $t3, 0($t2)                      # Mark the gems as 1 for deletion afterwards
    sw $t3, 40($t2)
    sw $t3, 80($t2)
    
# Skip to the next column (grid on a row)
down_left_next_col:
    addi $t9, $t9, 1                    # Increment column counter
    blt $t9, $t4, down_left_col_loop    # Continue loop if boundary hasn't been reached
    
    addi $t8, $t8, 1                    # Increment row counter (next row)
    blt $t8, $t6, down_left_row_loop    # Continue loop if boundary hasn't been reached
    
    lw $s2, 0($sp)                      # Restore ra & pop color values
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16                        
    jr $ra
    
##############################################################################    
# Check diagonal down right: perform a diagonal down_right scan on any diagonal 3-in-a-row gems
#   $s0 = Color of current gem
#   $s1 = Color of second gem (one row down)
#   $s2 = Color of third gem (two rows down)
#   $t0 = Holder for width of playing field (11)
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Marker for match (marking 1 in match_grid for gems that needs deletion)
#   $t4 = Holder for width - 2 of playing field (9)
#   $t5 = Holder of memory of playable grid & temporary grid
#   $t6 = Holder for height - 2 of the playing field (20)
#   $t8 = Counter for the rows/Y coordinates (looping from 0-17, for Y+2)
#   $t9 = Counter for the columns/X coordinates (0-10)
##############################################################################
check_down_right_matches:
    addi $sp, $sp, -16                  # Preserve ra & colors in s0-2 (prevents override in collision)
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    
    li $t8, 0                           # Initialize the row counter
    li $t4, 9                           # Load the width - 2
    li $t6, 18                          # Load the height of playing field (20)

# Loop over the rows of the playing field
down_right_row_loop:
    li $t9, 0                           # Initialize the column index counter

# Loop through the grid of each row
down_right_col_loop:
    # Calculate the index of current gem in memory
    lw $t0, grid_width                  # Load width of playing field
    mult $t8, $t0                       # Address for start of current row         
    mflo $t1
    add $t1, $t1, $t9                   # Add the column offset
    sll $t1, $t1, 2                     # Multiply by 4 to get index in memory
    
    # Load the colors
    la $t5, grid                        # Load the memory of the grid
    add $t2, $t5, $t1                   # Get the address of the current gem
    lw $s0, 0($t2)                      # Load the 1st gem's color
    lw $s1, 48($t2)                     # Load 2nd gem's color (Down 1 & Right 1: 44 + 4)
    lw $s2, 96($t2)                     # Load 3rd gem's color (Down 2 & Right 2: 88 + 8)
    
    # Check for matches
    beq $s0, $zero, down_right_next_col       # Check if current grid is empty (if so, no match)
    bne $s0, $s1, down_right_next_col         # Check if the second gem has same color (if not, move to next loop)
    bne $s0, $s2, down_right_next_col         # Check the third gem
    
    # If all checks passed: Diagonal 3-in-a-row -> Mark the match_grid for deletion
    la $t5, match_grid                  # Load the temporary grid
    add $t2, $t5, $t1                   # Similarly, get address for current gem
    li $t3, 1                           # Load the marker
    sw $t3, 0($t2)                      # Mark the gems as 1 for deletion afterwards
    sw $t3, 48($t2)
    sw $t3, 96($t2)

# Skip to the next column (grid on a row)
down_right_next_col:
    addi $t9, $t9, 1                    # Increment column counter
    blt $t9, $t4, down_right_col_loop   # Continue loop if boundary hasn't been reached
    
    addi $t8, $t8, 1                    # Increment row counter (next row)
    blt $t8, $t6, down_right_row_loop   # Continue loop if boundary hasn't been reached
    
    lw $s2, 0($sp)                      # Restore ra & pop color values
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16                        
    jr $ra

##############################################################################
# Delete matches
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $a2 = Load the black palette from $t7 to pain pixel
#   $v0 = Checker for deletion of gems
#   $t0 = Holder for width of playing field (11) - s0
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Marker for match (marking 1 in match_grid for gems that needs deletion)
#   $t4 = Holder for height of playing field (20) - s1
#   $t5 = Holder of memory of temporary grid
#   $t6 = Holder of memory of playable grid
#   $t7 = Black palette for repainting
#   $t8 = Counter for the rows/Y coordinates (0-19) - s2
#   $t9 = Counter for the columns/X coordinates (0-10) - s3
##############################################################################
delete_match:
    addi $sp, $sp -20                   # Save parameters that might be affected by draw_pixel
    sw $ra, 16($sp)
    sw $s0, 12($sp)                     # Save the width
    sw $s1, 8($sp)                      # Height
    sw $s2, 4($sp)                      # Counters
    sw $s3, 0($sp)
    
    lw $s0, grid_width                  # Load width of playing field
    lw $s1, grid_height                 # Load height of playing field
    li $s2, 0                           # Initialize the row counter
    li $v0, 0                           # Initialize deletion checker

del_row_loop:
    li $s3, 0                           # Initialize the column counter
    
del_col_loop:
    # Calculate index in match_grid
    mult $s2, $s0                       # Address for start of current row
    mflo $t1
    add $t1, $t1, $s3                   # Add the column offset
    sll $t1, $t1, 2                     # Multiply by 4 to get index in memory
    
    # Check the current match_grid for deletion marking
    la $t5, match_grid                   # Load match_grid memory
    add $t5, $t5, $t1                   # Get the address in match_grid
    lw $t3, 0($t5)                      # Get the deletion marker (0/1)
    beq $t3, $zero, skip_del            # If val is not 1, doesn't need to delete
    
    sw $zero, 0($t5)                    # Reset the match_grid marker status
    la $t6, grid                        # Load the playable grid
    add $t6, $t6, $t1                   # Get current gem's address in playable grid
    sw $zero, 0($t6)                    # Reset the value in grid to 0 (unoccupied)
    
    # Update deletion in playing field
    addi $a0, $s3, 5                    # Loading the (X, Y) coordinate of the gem that needs deletion
    addi $a1, $s2, 5
    la $t7, black_palette               # Load the black palette for deletion
    lw $a2, 0($t7)
    jal draw_pixel                      # Paint the pixel black (delete it)
    li $v0, 1                           # Update checker - sth has been deleted, look for chain reactions

skip_del:
    addi $s3, $s3, 1                    # Increment column counter
    blt $s3, $s0, del_col_loop          # Keep looping if boundary not reached
    
    addi $s2, $s2, 1                    # Increment row counter
    blt $s2, $s1, del_row_loop          # Keep looping if boundary not reached  
    
    lw $s3, 0($sp)                      # Pop all stored values from stack
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)                     # Restore ra
    addi $sp, $sp, 20
    jr $ra                              # Return

##############################################################################
# Collapse columns: Drop any hovering gems after match deletion
#   $a0 = Current X coordinate of column (topmost gem)
#   $a1 = Current Y coordinate of column (topmost gem)
#   $a2 = Load the black palette from $t7 to pain pixel
#   $s0 = Width of playing field
#   $s1 = Height of playing field
#   $s2 = Counter for the rows/Y coordinates (0-19)
#   $s3 = Counter for the columns/X coordinates (0-10)
#   $s4 = Check if anything has been dropped
#   $t0 = Holder of index of first row (0) - for the counter
#   $t1 = Byte offset of current gem (in memory)
#   $t2 = Address of current gem (in memory)
#   $t3 = Color of the current gem
#   $t7 = Black palette for repainting
##############################################################################
collapse_columns:
    addi $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s0, 20($sp)                     # Width
    sw $s1, 16($sp)                     # Height
    sw $s2, 12($sp)                     # X counter
    sw $s3, 8($sp)                      # Y counter
    sw $s4, 4($sp)                      # Dropped gem flag
    sw $s5, 0($sp)                      # Temp color storage
    
    lw $s0, grid_width
    lw $s1, grid_height

collapse_outer_loop:
    li $s4, 0                           # Initialize/reset Drop flag to 0
    li $s2, 0                           # Start at Col 0
    
col_loop:
    addi $s3, $s1, -1                   # Start at Bottom Row (19)

row_loop:
    # Calculate Index for (X, Y)
    mult $s3, $s0
    mflo $t1
    add $t1, $t1, $s2
    sll $t1, $t1, 2                     # Byte offset for current gem (Bottom-most) in memory
        
    la $t0, grid
    add $t2, $t0, $t1                   # Address of current grid 
    lw $t3, 0($t2)                      # Load current color
        
    bne $t3, $zero, next_row            # If not empty, we can't drop anything here
    
    # Check the spot above the grid
    lw $s5, -44($t2)                    # Load color from one row up (-11 words = -44 bytes)
    beq $s5, $zero, next_row            # If above is also empty, nothing to drop
    
    # Drop the gem
    sw $s5, 0($t2)                      # Move color down
    sw $zero, -44($t2)                  # Clear old spot
    li $s4, 1                           # Mark for dropping

    # Draw gem at new position
    addi $a0, $s2, 5                    # Reload current coordinates (X, Y) in playing field
    addi $a1, $s3, 5  
    move $a2, $s5                       # Color of dropped gem
    jal draw_pixel
    
    # Repaint old position to black
    addi $a0, $s2, 5                    # Get (X, Y) coordinates on screen
    addi $a1, $s3, -1                   # The row above current grid (position before dropping)
    addi $a1, $a1, 5
    la $t7, black_palette
    lw $a2, 0($t7)
    jal draw_pixel

next_row:
    addi $s3, $s3, -1                   # Decrement row - move to row above
    li $t0, 0
    bgt $s3, $t0, row_loop              # Continue looping id the top row has not been reached 
    
    addi $s2, $s2, 1
    blt $s2, $s0, col_loop
    
    # Repeat the scanning process if anything above the gem needs to be dropped as well
    bne $s4, $zero, collapse_outer_loop     # If anything has been moved, repeat loop
    
    lw $s5, 0($sp)                       # Pop the variables stored from stack
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $s0, 20($sp)
    lw $ra, 24($sp)                      # Restore ra
    addi $sp, $sp, 28   
    jr $ra
