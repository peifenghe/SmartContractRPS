# Rock-Paper-Scissors Smart Contract

A decentralized Rock-Paper-Scissors simulator.

---

## How to Use

### General Notes
- We use `$0$` to represent **Rock**, `$1$` for **Paper**, and `$2$` for **Scissors**.
- Input **1, 2, or 3** as your choice (instead of using strings).

---

### Steps to Play

#### 1. Reveal Scheme
##### a. **Deploy and Set Parameters**
- During deployment, specify the value `numToWin` (the number of games a player must win to claim overall victory).
- Use the `generateCommitment` function to create a commitment for your move.  
  **Example:**  
  - Choice: `1` (Paper)  
  - Secret: `"a"`  
  - Resulting Commitment: `"0x851ad..."`  
  > *Note: Normally, this is done offline for security, but this guide simplifies testing with an all-in-one approach.*

##### b. **Create a Game (Player 1)** 
- Switch to an account for Player 1.  
- Set a betting value (e.g., `10 ethers`).  
- Call `createGame`.

##### c. **Commit Your Choice (Player 1)** 
- Call `commitChoice` and enter the commitment generated in step **a**.  
  **Example:** `commitment: "0x851ad..."`

##### d. **Join the Game (Player 2)** 
- Switch to another account for Player 2.  
- Enter the same betting value as Player 1.  
- Call `joinGame` using the GameID provided during game creation.

##### e. **Player 2 Makes a Move**
- Call `player2play` and enter Player 2's choice.  
  **Example:** Choice: `2` (Scissors).

##### f. **Reveal Player 1's Move** 
- Switch back to Player 1.  
- Call `reveal` with Player 1’s choice and secret from step **a**.  
  Check the output to see the winner for this round.

##### g. **Start a New Round (Player 1)** 
- Call `generateCommitment` with a new choice and secret to start another round.
- Repeat steps **c**, **d**, and **f** until the required number of rounds (specified by `numToWin`) is completed.

---

Happy playing! 🎮
