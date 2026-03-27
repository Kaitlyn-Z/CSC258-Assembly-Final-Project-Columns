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
    # Clear the screen (Implement later)

    # Initialize playing field & column
    jal draw_playing_field              # Call the Playing Field function
    jal generate_col                    # Generate current column (not displayed yet)
    
    # Draw the current column within the playing field
    lw $a0, curr_col_x                  # Load coordinates from playing field (middle top)
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Load the initialized color
    jal draw_curr_col
    
    # Call generate_col again to generate the next column
    # (Consider later) Whether to call generate_col again here to make it preview the next column
    lw $a0, display_x                   # Load coordinates in display area 
    lw $a1, display_y
    la $t1, gem1_color                  # Load the initialized color
    jal draw_curr_col
    
# Create a game loop - updating ~60 times per second
game_loop:
    # Check the keyboard for inputs
    lw $t0, ADDR_KBRD                   # Go to the keyboard address
    lw $t2, 0($t0)                      # Get the first word to check input
    beq $t2, 0, skip_input              # If no key pressed: Branch directly to next loop
    # THIS PART WILL BE CHANGED IN FUTURE FOR GRAVITY
    
    # If key has been pressed: compute movement based on key
    lw $t2, 4($t0)                      # Get the value of key
    beq $t2, 0x61, move_left            # If the key is "A", move left
    beq $t2, 0x64, move_right           # If the key is "D", move right
    beq $t2, 0x77, shuffle_col          # If the key is "W", shuffle the column
    beq $t2, 0x73, drop_at_once         # If the key is "S", drop the column all the way down
    
    beq $t2, 0x71, quit_game            # If key is "q", quit game
    
skip_input:
    li $a0, 16                          # Sleep for a certain amount of time
    li $v0, 32                          # Call sleep
    syscall
    
    j game_loop                         # Repeat the process
    
quit_game:
    li $v0, 10                          # Terminate gracefully
    syscall

##############################################################################
# Drawing the playing field
#   USED IN: main
#
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
# Drawing a horizontal line
#   USED IN: draw_playing_field
#
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
#   USED IN: draw_playing_field
#
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
#   USED IN: draw_hor_line, draw_ver_line, draw_curr_col, delete_match, collapse_col
#
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
#   USED IN: main, drop_at_once
#
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
#   USED IN: main
#
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
# Move left by one pixel (when "A" is pressed)
#   USED IN: 
#
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
#   USED IN:
# 
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
# Move down by 1 pixel
##############################################################################

##############################################################################
# Dropping a column to the bottom at once when "S" is pressed
#   USED IN:
# 
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
    addi $sp, $sp, -16                  # Clear up space on stack
    sw $ra, 12($sp)                     # Preserve ra
    sw $s0, 8($sp)                      # Preserve current X coordinate
    sw $s1, 4($sp)                      # Preserve current Y coordinate
    sw $s4, 0($sp)                      # Preserve the deletion checker
    
    lw $s0, curr_col_x                  # Initialize mutable coordinates for checking
    lw $s1, curr_col_y                  # Y coordinate is responsible for checking "bottom"    

drop_loop:
    addi $s1, $s1, 1                    # Move Y checker down by 1
    
    # Boundary check for reaching playing field bottom
    addi $t2, $s1, 2                    # Y coordinates for the bottom-most gem
    lw $t3, grid_bot                    # Load the bottom of the playing field
    addi $t3, $t3, -1                   # The first playable grid (one row up)
    bgt $t2, $t3, collision             # The bottom is hit (i.e., gem moves past playable area)
    
    # Collision check for reaching an existing gem
    move $a0, $s0                       # Retrieve the curr_x coordinates
    move $a1, $t2                       # Retrieve Y coordinates for bottom gem
    jal get_grid_value                  # Check for values in current position
    bne $v0, $zero, collision           # If the value is not 0, the grid is occupied
    
    j drop_loop                         # Keep moving down

##############################################################################
# Shuffle the columns when "W" is pressed (top->mid, mid->bot, bot->top)
#   USED IN:
#
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
#   USED IN:
#
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
#   USED IN: 
#
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
#   USED IN: 
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
chain_reaction_loop:
    # Check 3-in-a-row in conditions: vertical, horizontal, diagonal
    jal check_vertical_matches
    jal check_horizontal_matches
    jal check_down_left_matches
    jal check_down_right_matches
    
    # Apply deletions
    jal delete_match
    move $s4, $v0
    beq $s4, $zero, end_chain_reaction_loop      # Stop chain reaction if nothing continues to be deleted
    
    # Drop any hovering gems
    # TODO: probably change after implementing gravity
    jal collapse_columns
    
    j chain_reaction_loop               # Continue checking for new matches
    
end_chain_reaction_loop:
    # Check for Game Over condition (column hits top)
    jal check_game_end
    
    # Re-initialze coordinates for next piece
    jal respawn
    jal generate_col                    # Generate new column at initial position
    lw $a0, curr_col_x                  # Load the initialized position     
    lw $a1, curr_col_y
    la $t1, gem1_color                  # Get the new gem color
    jal draw_curr_col                   # Draw the new column in playing field 
    
    # Update the column in the display area 
    lw $a0, display_x                   # Load coordinates in display area 
    lw $a1, display_y
    la $t1, gem1_color                  # Load the initialized color
    jal draw_curr_col                   # Draw the new column
    lw $a0, curr_col_x                  # Change the values in $a0, $a1 to coordinates in playing field
    lw $a1, curr_col_y
    
    # Restore the stack in order
    lw $s4, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16                   # Pop one-by-one in reverse
        
    j game_loop                         # Jump back to game_loop & wait for next key
    
##############################################################################
# Lock current column in place & store it in grid memory
#   USED IN:
#
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
#   USED IN:
#
#   $t0 = Holder for end condition values (edge of playable area)
#   $t1 = Current Y coordinate of column (topmost gem)
##############################################################################
# !! THIS NEEDS FIXING: RIGHT NOW GAME ENDS BUT WITH OVERLAP!! - FIX WHEN IMPLEMENTING GRAVITY
check_game_end:
    li $t0, 5                           # Load $t0 with the highest playable area (1 row under ceiling)
    lw $t1, curr_col_y                  # Check the position of current column
    ble $t1, $t0, quit_game             # If column is higher than playable area, it has reached the ceiling
    jr $ra

##############################################################################
# Restore X and Y coordinates to initial position
#   USED IN:  (to generate new column)
#
#   $t0 = Holder for current X/Y coordinates
##############################################################################
respawn:
    li $t0, 10                          # Initial X offset
    sw $t0, curr_col_x                  # Re-initialize current X coordinates
    li $t0, 5                           # Initial Y offset
    sw $t0, curr_col_y                  # Re-initialize Y
    jr $ra

##############################################################################
# Check vertical matches: perform scan on any vertical 3-in-a-row gems
#   USED IN:
# 
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
#
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
    la $t5, match_grid                   # Load the temporary grid
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
#
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
    la $t5, match_grid                   # Load the temporary grid
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
#
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
    la $t5, match_grid                   # Load the temporary grid
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
# MODIFY VARIABLE DOCUMENTATION!
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
    
