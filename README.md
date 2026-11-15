# Sub-67

This is a card game we made in 24 hours for [Hackclub Haven](https://haven.hackclub.com), the theme was "Bounce Back"!

## Rules and Gameplay

- 2 Players
-   Each must either Play a card or draw one (and add 5 points to the score) on their move
-   Whoever sets the counter to 67 Points or higher loses
-   There are all the cards from 0-10, adding their corresponding values to the score, plus special cards with certain abilities.
      - Special cards:
      -   "-5, -10": remove 5/10 from the score
      -   "discard": discards 2 random cards from your enemy
      -   "skip": lets you skip a turn so the enemy ramps up points alone
      -   "x2, +3": if the enemy plays a number, multiplies the enemies next move by 2/adds 3pts to the score with their move
      -   "death card": sets the score to 65 instantly
-   Every ~20 seconds, the timer in the top left runs out, and whoever was playing by then gets debuffed, while the enemy gets "buffed"
    - "Debuff": Players clock "bounces" forward, withering away a couple random cards
    - "buff": Players clock bounces back (aha i said the theme name) and they gain the last 2-3 cards that were played onto the main pile.

<img width="857" height="476" alt="image" src="https://github.com/user-attachments/assets/1a0b9fcd-8abc-438e-9336-6108830ba5ae" />

<img width="1656" height="933" alt="image" src="https://github.com/user-attachments/assets/ac7c139c-7d53-442d-abcd-b4863ccddb2b" />
^^ Top red bar shrinks with the timer, shows the amount of time left before a warp occurs. Clocks are in sync for the first part, then move back/forwards depending on whether the player was buffed/debuffed

The ui was inspired a bit by balatro, even though i never touched that thing, but we thought it looked cool !!

## Tech stack

The game was made in Godot 4.7.2, and is available to play on [itch.io](https://ilikemicee.itch.io/sub-67)!
