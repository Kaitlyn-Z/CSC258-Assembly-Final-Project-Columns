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
    palette: .word 0xff0000, 0xffa500, 0xffff00, 0x00ff00, 0x0000ff, 0x800080
    grid_color: .word 0x808080    # Gray for boundaries
    black_palette: .word 0x000000, 0x000000, 0x000000 # A palette with only black - for repaiting grid cells
    
    # Parameters for the playing field:
    # Information about the grid
    grid_x_offset: .word 4
    grid_y_offset: .word 4
    grid_width:    .word 11         # Playable width (excluding walls)
    grid_height:   .word 20         # Playable height (excluding walls)
    grid_full_wid: .word 13         # Playable width + 2
    grid_full_hei: .word 22         # Playable height + 2
    
    # Parameters calculated for drawing playing field
    grid_left: .word 4      # Same as x_offset
    grid_right: .word 16    # (left + width + 1) 
    grid_top: .word 4       # Same as y_offset
    grid_bot: .word 25      # (top + height + 1)
    
    # Parameters for current/next column diplay OUTSIDE of playing field
    display_x: .word 20     # grid_right + 4
    display_y: .word 10     

##############################################################################
# Mutable Data - Game State (Memory Variables)
##############################################################################
    curr_col_x:  .word 10      # Initializing X point for column: middle of grid ceiling
    curr_col_y:  .word 5       # Initializing Y point for column: one block beneath the grid ceiling
    gem1_color:  .word 0       # Color of the gems 
    gem2_color:  .word 0
    gem3_color:  .word 0

    # The Grid (220 words for 11x20 field)
    grid: .word 0:220

##############################################################################
# Main Program Execution
.text
.globl main

### Variables
### - $a0 = The X coordinate of the column (being painted) & time for sleep
### - $a1 = The Y coordinate of the column (being painted)
### - $t0 = default display address + keyboard address
### - $t1 = current position of topmost gem (where to draw col)
### - $t2 = status of the keyboard (whether there is key-press & what key it is)

main:
    # Clear the screen (Implement later)

    # Initialize playing field & column
    jal draw_playing_field  # Call the Playing Field function
    jal generate_col        # Generate current column (not displayed yet)
    
    # Draw the current column within the playing field
    lw $a0, curr_col_x      # Load coordinates from playing field (middle top)
    lw $a1, curr_col_y
    la $t1, gem1_color      # Load the initialized color
    jal draw_curr_col
    
    # Call generate_col again to generate the next column
    # (Consider later) Whether to call generate_col again here to make it preview the next column
    lw $a0, display_x              # Load coordinates in display area 
    lw $a1, display_y
    la $t1, gem1_color             # Load the initialized color
    jal draw_curr_col
    
    # Create a game loop - updating ~60 times per second
    # Within the loop:
    game_loop:
    
    # Check the keyboard for inputs
    lw $t0, ADDR_KBRD               # Go to the keyboard address
    lw $t2, 0($t0)                  # Get the first word to check input
    beq $t2, 0, skip_input          # If no key pressed: Branch directly to next loop
    # THIS PART WILL BE CHANGED IN FUTURE FOR GRAVITY
    
    # If key has been pressed: compute movement based on key
    lw $t2, 4($t0)                  # Get the value of key
    beq $t2, 0x61, move_left        # If the key is "A", move left
    beq $t2, 0x64, move_right       # If the key is "D", move right
    beq $t2, 0x77, shuffle_col      # If the key is "W", shuffle the column
    beq $t2, 0x73, drop_at_once     # If the key is "S", drop the column all the way down
    
    beq $t2, 0x71, quit_game        # If key is "q", quit game
    
    skip_input:
    # Sleep for a short while before repeating the process
    li $a0, 16              # Sleep for a certain amount of time
    li $v0, 32              # Call sleep
    syscall
    
    j game_loop             # Repeat the process
    
    quit_game:
    li $v0, 10              # Terminate gracefully
    syscall
##############################################################################
    
##############################################################################
# Helper Functions
##############################################################################

# NOTE: Caluculation for bitmap address = base address + (Y*row_size_bytes) + X*4
#       MAKE AN EXCEL SHEET to keep track of the status of registers during each function!!

##############################################################################
# Helper Functions
##############################################################################

### Drawing the playing field
### Variables:
### $a0 - The X coordinate for start of a vertical/horizontal line
### $a1 - The Y coordinate for start of a vertical/horizontal line
### $a2 - The color of the grid (all gray for boundaries)
### $a3 - The length of the line being drawn (full width/height)

draw_playing_field:
    addi $sp, $sp, -4              # Preserve ra
    sw $ra, 0($sp)

    # Draw Top Wall
    lw $a0, grid_left              # X start
    lw $a1, grid_top               # Y start (Top of grid)
    lw $a2, grid_color             # Color (Gray)
    lw $a3, grid_full_wid          # Full width
    jal draw_hor_line

    # Draw Bottom Wall
    lw $a0, grid_left              # X start
    lw $a1, grid_bot               # Y start (Bottom of grid)
    lw $a2, grid_color             # Color
    lw $a3, grid_full_wid          # Full width
    jal draw_hor_line

    # Draw Left Wall
    lw $a0, grid_left               # X start
    lw $a1, grid_top                # Y start (Top of grid)
    lw $a2, grid_color              # Color
    lw $a3, grid_full_hei           # Full height
    jal draw_ver_line

    # Draw Right Wall
    lw $a0, grid_right              # X start (Right side)
    lw $a1, grid_top                # Y start (Top of grid)
    lw $a2, grid_color              # Color
    lw $a3, grid_full_hei           # Full height
    jal draw_ver_line

    lw $ra, 0($sp)                  # Restore ra
    addi $sp, $sp, 4
    jr $ra


### Drawing a horizontal line
### Variables:
### - $a0 = The X coordinate of the start of the line
### - $a1 = The Y coordinate of the start of the line
### - $a2 = The color of the line
### - $a3 = The length of the horizontal line
### - $t0 = Location of the top-left corner of the bitmap
### - $t1 = The index counter for tracking line length

draw_hor_line:
addi $sp, $sp, -4               # Save the return address (ra)
sw $ra, 0($sp)                  # Load ra onto the stack
add $t1, $zero, $zero           # Initialize the index counter at 0

# Loop through the line & draw pixels one by one
hor_line_loop:
beq $t1, $a3, end_hor_loop      # End loop if index counter increments to length
jal draw_pixel                  # Draw the pixel at the current location
addi $a0, $a0, 1                # Move the X coordinates right for 1 row
addi $t1, $t1, 1                # Increment the counter
j hor_line_loop                 # Repeat the process

end_hor_loop:
lw $ra, 0($sp)                  # Restore the ra
addi $sp, $sp, 4  
jr $ra


### Drawing a vertical line
### Variables:
### - $a0 = The X coordinate of the start of the line
### - $a1 = The Y coordinate of the start of the line
### - $a2 = The color of the line
### - $a3 = The length of the vertical line
### - $t0 = Location of the top-left corner of the bitmap
### - $t1 = The index counter for tracking line length

draw_ver_line:
addi $sp, $sp, -4               # Save the return address (ra)
sw $ra, 0($sp)                  # Load ra onto the stack
add $t1, $zero, $zero           # Initialize the index counter to 0

# Loop through the line & draw pixels one by one
ver_line_loop:
beq $t1, $a3, end_ver_loop      # End loop if index counter increments to length
jal draw_pixel                  # Draw the pixel at the current location
addi $a1, $a1, 1                # Move the coordinates down for 1 row
addi $t1, $t1, 1                # Increment the counter              
j ver_line_loop                 # Repeat the process

end_ver_loop:
lw $ra, 0($sp)                  # Restore the ra
addi $sp, $sp, 4  
jr $ra


### Drawing a single pixel
### Variables:
### - $a0 = The X coordinate of the pixel
### - $a1 = The Y coordinate of the pixel
### - $a2 = The color of the gem
### - $t0 = display address
### - $t8 = X offset
### - $t9 = Y offset

draw_pixel:
# Boundary check - go to skip if condition fails
# Skip this section for now

# Pain the pixel in corresponding location
sll $t8, $a0, 2                 # Calculate the bitmap location based on X (times 4)
sll $t9, $a1, 7                 # Calculate the bitmap location based on Y (times 128)

lw $t0, displayaddress          # load the diplay address
addu $t0, $t0, $t8              # Add X offset
addu $t0, $t0, $t9              # Add Y offset
sw $a2, 0($t0)                  # Paint the pixel with color in $a2

skip:
jr $ra                          # End of function


### Generating a column with random colors (in memory, not displayed yet)
### Variables:
### - $a0 = Index pointing to a color (random selection)
### - $t1 = Index counter for number of gems
### - $t2 = Store memory address of the gems (starting with 1st)
### - $t3 = Color address for each gem (based on random selection)
### - $t4 = Storage of actual color
### - $t5 = Number of gems

generate_col:
addi $sp, $sp, -4               # Preserve ra
sw $ra, 0($sp)                  # Load ra onto the stack
li $t1, 0                       # Initialize gem counter
li $t5, 3                       # Load the total number of gems (3)
la $t2, gem1_color              # Point to the memory address of the 1st gem

# Loop through 3 gems & generate random colors for each
generate_col_loop:
beq $t1, $t5, end_generate_col_loop      # Break loop if all 3 gem colors have been initiated
li $v0, 42                      # Random generation
li $a0, 0                       # Set range from 0-5 (corresponding to six colors)
li $a1, 6
syscall                         # Store the random selected index in $a0

sll $a0, $a0, 2                 # Get color's address in memory (index * 4 bytes)
la $t3, palette                 # Point to the start of the palette
addu $t3, $t3, $a0              # Based on the address, get the corresponding color
lw $t4, 0($t3)                  # Load the value of the color
sw $t4, 0($t2)                  # Store the color in the memory (gem_color_i)

addi $t2, $t2, 4                # Move to the next gem
addi $t1, $t1, 1                # Increment index counter
j generate_col_loop

end_generate_col_loop:
lw $ra, 0($sp)                  # Restore the ra
addi $sp, $sp, 4  
jr $ra


### Drawing the current column
### Variables:
### - $a0 = Current X coordinate of column (topmost gem)
### - $a1 = Current Y coordinate of column (topmost gem)
### - $a2 = Current gem's color
### - $t1 = Starting point of address of generated gem colors
### - $t2 = Index counter
### - $t3 = Number of gems
### - $t4 = Temporary safety storage for $a0
### - $t5 = Temporary safety storage for $a1

draw_curr_col:
addi $sp, $sp, -4               # Preserve ra
sw $ra, 0($sp)                  # Load ra onto the stack

# lw $a1, curr_col_y            # removed to let main handle position
# la $t1, gem1_color            # Get current gem's color address - handled by other functions when calling
li $t2, 0                       # Initialize counter
li $t3, 3                       # Initialize number of gems

draw_curr_col_loop:
beq $t2, $t3, end_draw_curr_col_loop    # End loop when all 3 gems have been painted
# lw $a0, curr_col_x                    # Load current column position - removed to let main handle position

move $t4, $a0                           # Temporarily save $a0 just in case
move $t5, $a1                           # Similarly for $a1
lw $a2, 0($t1)                          # Load the color of the current gem
jal draw_pixel                          # Draw the pixel at corresponding location
move $a0, $t4                           # Restore the values
move $a1, $t5

addi $a1, $a1, 1                        # Move to next gem (increment Y)
addi $t1, $t1, 4                        # Move to next gem color address in memory
addi $t2, $t2, 1                        # Increment counter
j draw_curr_col_loop

end_draw_curr_col_loop:
lw $ra, 0($sp)                          # Restore ra
addi $sp, $sp, 4
jr $ra


### Move left when "A" is pressed
### Variables:
### - $a0 = Current X coordinate of column (topmost gem)
### - $a1 = Current Y coordinate of column (topmost gem)
### - $t1 = Current color of the gems
### - $t2 = Placeholder for updating new gem position in memory
### - $t3 = Position of left grid wall

move_left:
# Boundary check
lw $t2, curr_col_x          # Load current position
lw $t3, grid_left           # Load left wall position
addi $t3, $t3, 1            # The first playable position within the field
beq $t2, $t3, game_loop     # If the column is already at edge, go back to loop (no update)

# Erase the column in old position
lw $a0, curr_col_x          # Get the current positions of topmost gem
lw $a1, curr_col_y
la $t1, black_palette       # Get the black palette for painting
jal draw_curr_col           # Erase the old column (repaint with black)

# Update position (X coordinate)
lw $t2, curr_col_x          # Load the current column position
addi $t2, $t2, -1           # Move left by 1
sw $t2, curr_col_x          # Renew the updated X coordinate in memory

# Draw the (same) column in new position
lw $a0, curr_col_x          # Load in the new coordinates
lw $a1, curr_col_y
la $t1, gem1_color          # Get the gem palette for normal drawing
jal draw_curr_col

j game_loop                 # Move back to the game loop for next check


### Move right when "D" is pressed
### - $a0 = Current X coordinate of column (topmost gem)
### - $a1 = Current Y coordinate of column (topmost gem)
### - $t1 = Current color of the gems
### - $t2 = Placeholder for updating new gem position in memory
### - $t3 = Position of left grid wall

move_right:
# Boundary check
lw $t2, curr_col_x          # Load current position
lw $t3, grid_right          # Load right wall position
addi $t3, $t3, -1           # The first playable position within the field
beq $t2, $t3, game_loop     # If the column is already at edge, go back to loop (no update)

# Erase the column in old position
lw $a0, curr_col_x          # Get the current positions of topmost gem
lw $a1, curr_col_y
la $t1, black_palette       # Get the black palette for painting
jal draw_curr_col           # Erase the old column (repaint with black)

# Update position (X coordinate)
lw $t2, curr_col_x          # Load the current column position
addi $t2, $t2, 1            # Move right by 1
sw $t2, curr_col_x          # Renew the updated X coordinate in memory

# Draw the (same) column in new position
lw $a0, curr_col_x          # Load in the new coordinates
lw $a1, curr_col_y
la $t1, gem1_color          # Get the gem palette for normal drawing
jal draw_curr_col

j game_loop                 # Move back to the game loop for next check


### Shuffle the columns when "W" is pressed (top->mid, mid->bot, bot->top)
### Variables:
### - $a0 = Current X coordinate of column (topmost gem)
### - $a1 = Current Y coordinate of column (topmost gem)
### - $t0 = Color of top gem
### - $t1 = Color of middle gem
### - $t2 = Color of bottom gem

shuffle_col:
# Load current colors of the column
lw $t0, gem1_color          # top
lw $t1, gem2_color          # mid
lw $t2, gem3_color          # bot

# Swap the colors in order
sw $t2, gem1_color          # bot->top
sw $t0, gem2_color          # top->mid
sw $t1, gem3_color          # mid->bot

# Redraw the column at same position with shuffled colors
lw $a0, curr_col_x
lw $a1, curr_col_y
la $t1, gem1_color          # The new gem color order
jal draw_curr_col

# TO BE CHANGED: Redraw the displayed column (on the side) if we decide to display current col
# IGNORE if display/preview next col (no need to update with shuffle)

j game_loop                 # Return to the game loop for next input


### Check if a grid within the playing field is occupied
### Variables:
### - $a0 = Current X coordinate of column (topmost gem)
### - $a1 = Current Y coordinate of column (topmost gem)
### - $t0 = Holder of width of playing field & initial address of grid
### - $t1 = Index of (X, Y) coordinate in memory
### - $v0 = Value of grid being checked (returns color, or 0 if empty)
### - $t8 = Relative position of X in the memory of playing field (0-10)
### - $t9 = Relative position of Y in the memory of playing field (0-19)

get_grid_value:
# Translate the current (X, Y) coordinates to memory address
addi $t8, $a0, -5            # Reset the X, Y offset to 0 (for memory)
addi $t9, $a1, -5

# Calculate the index of the current coordinate in memory
lw $t0, grid_width           # Load the width of the playing field (currently 11)
mult $t9, $t0                # Skip over the previous rows
mflo $t1                     # Update the Y coordinate in memory (get the current row)
add $t1, $t1, $t8            # Add to the current X coordinate (get the current column)
sll $t1, $t1, 2              # Convert index into bytes (direct access to memory)

la $t0, grid                 # Load the starting point of grid memory
add $t1, $t0, $t1            # Move to the current point
lw $v0, 0($t1)               # Load the value (color) in that grid to $v0

jr $ra                       # Exit the function

### Dropping a column to the bottom at once when "S" is pressed
### Variables:
### - $s0 = (Safety storage) Current X coordinate of column (topmost gem)
### - $s1 = (Safety storage) Current Y coordinate of column (topmost gem)
### - $a0 = Holder for X coordinate of column (topmost gem)
### - $a1 = Holder for Y coordinate of column (topmost gem)
### - $s2 = Placeholder for backup
### - $t1 = Current color of the gems
### - $t2 = Y coordinates for bottom-most gem
### - $t3 = Holder of value for bottom of playing field

drop_at_once:
addi $sp, $sp, -16          # Clear up space on stack
sw $ra, 12($sp)             # Preserve ra
sw $s0, 8($sp)              # Preserve current X coordinate
sw $s1, 4($sp)              # Preserve current Y coordinate
sw $s2, 0($sp)              # Preserved safety space just in case

lw $s0, curr_col_x          # Initialize mutable coordinates for checking
lw $s1, curr_col_y          # Y coordinate is responsible for checking "bottom"    

drop_loop:
addi $s1, $s1, 1            # Move Y checker down by 1

# Boundary check for reaching playing field bottom
addi $t2, $s1, 2            # Y coordinates for the bottom-most gem
lw $t3, grid_bot            # Load the bottom of the playing field
addi $t3, $t3, -1           # The first playable grid (one row up)
bgt $t2, $t3, collision     # The bottom is hit (i.e., gem moves past playable area)

# Collision check for reaching an existing gem
move $a0, $s0               # Retrieve the curr_x coordinates
move $a1, $t2               # Retrieve Y coordinates for bottom gem
jal get_grid_value          # Check for values in current position
bne $v0, $zero, collision   # If the value is not 0, the grid is occupied

j drop_loop                 # Keep moving down


# Perform the repainting of collision
collision:
# Erase the previous position
addi $s1, $s1, -1           # Move up by 1
lw $a0, curr_col_x          # Load column positions
lw $a1, curr_col_y
la $t1, black_palette       # Color them black
jal draw_curr_col
sw $s1, curr_col_y          # Renew the curr_col position

# Draw at the new unoccupied area
lw $a0, curr_col_x          # Load the inputs
lw $a1, curr_col_y
la $t1, gem1_color          # Load the colors of the gems
jal draw_curr_col

# Restore the stack in order
lw $s2, 0($sp)
lw $s1, 4($sp)
lw $s0, 8($sp)
lw $ra, 12($sp)
addi $sp, $sp, 16           # Pop one-by-one in reverse
    
j game_loop                 # Jump back to game_loop & wait for next key
