# final project notes
- [vga display code](https://github.com/muhammadaldacher/FPGA-Design-of-a-Digital-Analog-Clock-Display-using-Digilent-Basys3-Artix-7/tree/master/LAB4_Display%20on%20VGA)




what do we need to do now:
- [x] fix catching (when you also have the condition of forcing the level to be pulled down at beginning)
- [x] game starts after countdown
- [x] show start message
- [x] final score on bcd display
- [X] difficulty level doesn't seem to actually make stuff faster
- [ ] make the time btwn sticks being dropped also random

bugs:
- [ ] some sticks stay yellow at bottom of screen and we just never drop another stick
    - this never happens with leftmost stick (always turns red when fallen)


- [ ] Sometimes sticks immediately turn red at top of screen even though switch was not pulled on. This happens when another stick was already pulled high when it should not have been
    - okay so i thought this was fixed, but its actually still present, happens when another stick is toggled up and correctly turns red. Sometimes another white stick also then turns red immediately
    - this is clearest on level 9 for some reason
