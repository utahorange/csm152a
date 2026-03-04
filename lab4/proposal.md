Proposal
We plan to use the Basys3 FPGA with a VGA peripheral to the monitor to create an electronic version of the “stick-dropping” game, where sticks are randomly dropped from an apparatus and the player has to catch them in time. See this Instagram Reel for a visual demonstration of the game in real life. 
Functions
We plan to use the VGA module and an external monitor in conjunction with the Basys3 FPGA board in order to display information for the player(s), and the switches on the FPGA will be how the user selects a stick to “catch.” 

The display will initially show a Start screen, and the user can use the left and right circular buttons to control the difficulty level. The difficulty level is displayed on the BCD digit display and inversely proportional to the number of milliseconds the user has to “catch” the sticks by flipping the correct switches. 

When the user initially clicks the middle circular button, the BCD display will show a countdown from 3 seconds all the way down to 1 second. At this point, the screen will show 16 white, upright rectangles next to each other, separated by black lines. A rectangle will be randomly chosen by the FPGA, and it will take the following behavior:
It will initially turn yellow when randomly chosen by the FPGA.
When the time available for the user to “catch” the “stick” ends, the rectangle will:
Turn green in the case that the user flipped the switch at the correct time
Turn red in the case that the user flipped the switch at the incorrect time

After a stick is either caught or not caught, the FPGA will wait for a few seconds. Then, the next stick will be chosen, and the behavior will repeat. This is continued until all rectangles have been chosen (“dropped”) and thus all rectangles are either red or green. 

The user is prevented from flipping the switches before the stick was randomly chosen by the FPGA (turned yellow) because of the following:
The FPGA will check for the correct switch being 0 (off) immediately after the stick is randomly chosen, and then checks for a transition from 0→1 (off to on) during the window for correctness.

Once all of the sticks have been used (every stick is either red or green), the game will go back to the Start screen and show the game’s score on the BCD display. The user can then click the middle circular button to start a new game.
How Requirements are Met
	This project addresses the technical difficulty and creativity requirements. The technical difficulty requirement is addressed by using VGA controller as the additional peripheral device, and additionally using modules and features that have been previously implemented, along with new game logic. The creativity requirement is met by creating a project not listed in the possible project ideas and is a modern popular culture phenomenon (as seen on Instagram Reels).

# Pts / 36
Functional Requirements Completed
9
Displaying and updating rectangles with the right colors using VGA on the display/monitor.
9
Buttons and switches function correctly, and VGA is updated accordingly. This includes the reset button, interaction with “catching” sticks, and setting the difficulty (as displayed on the BCD display).
3
Timer countdown functional.
3
Score and start game message displayed at correct times.
12
Core game logic functions correctly. This includes:
Operating a switch before a stick drops does not do anything
Score is counted and displayed correctly
Sticks are chosen randomly

