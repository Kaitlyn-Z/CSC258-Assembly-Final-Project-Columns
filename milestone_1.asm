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
.eqv BASE_ADDRESS 0x10008000
.eqv ROW_SIZE     128           # 32 units * 4 bytes

.data
    displayaddress:     .word       0x10008000
    
    # Palette Array for Random Selection
    palette: .word 0xff0000, 0xffa500, 0xffff00, 0x00ff00, 0x0000ff, 0x800080
    grid_color: .word 0x808080    # Gray for boundaries
    
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
    curr_col_x:  .word 10      # Initializing X point for column: middle of grid
    curr_col_y:  .word 5       # Initializing Y point for column: one block beneath the grid ceiling
    gem1_color:  .word 0       # Color of the gems 
    gem2_color:  .word 0
    gem3_color:  .word 0

    # The Grid (90 words for 6x15 field)
    grid: .word 0:90

##############################################################################
# Main Program Execution
.text
.globl main

### Variables
### - $a0 = The X coordinate of the column (being painted)
### - $a1 = The Y coordinate of the column (being painted)
### - $t0 = default display address
### - $t1 = current position of topmost gem (where to draw col)

main:
    # Clear the screen (Implement later)

    jal draw_playing_field  # Call the Playing Field function
    jal generate_col        # Generate current column (not displayed yet)
    
    # Call generate_col again to generate the next column
    lw $a0, display_x              # Load coordinates in display area 
    lw $a1, display_y
    jal draw_curr_col
    
    # Draw the current column within the playing field
    lw $a0, curr_col_x      # Load coordinates from playing field (middle top)
    lw $a1, curr_col_y
    jal draw_curr_col
    
    li $v0, 10              # Gracefully terminate the program
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

### Drawing the playing field - NEEDS MODIFICATION
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


### Displaying the current column
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
la $t1, gem1_color              # Get current gem's color address
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

addi $a1, $a1, 1                        # Move to next gem (decrement Y)
addi $t1, $t1, 4                        # Move to next gem color address in memory
addi $t2, $t2, 1                        # Increment counter
j draw_curr_col_loop

end_draw_curr_col_loop:
lw $ra, 0($sp)                        # Restore ra
addi $sp, $sp, 4
jr $ra
