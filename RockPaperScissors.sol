// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

contract RockPaperScissorsController {
    enum Choice {
        ROCK,
        PAPER,
        SCISSORS,
        NONE
    }
    enum Phase {
        CREATED,
        BETTING,
        PLAYER1_COMMIT,
        PLAYER2_MOVE,
        PLAYER1_REVEAL,
        ENDED
    }

    struct Player {
        address playerAddress;
        Choice choice;
        uint256 winCount;
    }

    struct Bettor {
        address bettorAddress;
        uint256 amount;
        bool betOnPlayer1;
    }

    struct Game {
        Player player1;
        Player player2;
        bytes32 player1Commitment;
        uint256 betAmount; // Bet amount for each player
        bool gameEnded;
        Phase phase;
        uint256 totalBetsOnPlayer1;
        uint256 totalBetsOnPlayer2;
        mapping(address => Bettor) bettors;
    }

    address public contractOwner;
    mapping(uint256 => Game) public games;
    uint256 public gameCounter;
    uint256 public numToWin;

    event GameCreated(
        uint256 indexed gameId,
        address indexed player1,
        uint256 betAmount
    );
    event Player1Committed(uint256 indexed gameId);
    event Player2Joined(uint256 indexed gameId, address indexed player2);
    event Player1Revealed(uint256 indexed gameId, Choice choice);
    event GameRoundEnded(uint256 indexed gameId, string result);
    event MatchEnded(uint256 indexed gameId, address winner, uint256 amount);
    event OwnerFeeTransferred(
        uint256 indexed gameId,
        address owner,
        uint256 amount
    );
    event BetPlaced(
        uint256 indexed gameId,
        address indexed bettor,
        uint256 amount,
        bool betOnPlayer1
    );
    event BettorWinningsTransferred(
        uint256 indexed gameId,
        address indexed bettor,
        uint256 amount
    );

    modifier onlyPlayer1() {
        require(
            msg.sender == games[gameCounter].player1.playerAddress,
            "Only Player 1 can call this."
        );
        _;
    }

    modifier onlyPlayer2() {
        require(
            msg.sender == games[gameCounter].player2.playerAddress,
            "Only Player 2 can call this."
        );
        _;
    }

    modifier gameNotEnded() {
        require(!games[gameCounter].gameEnded, "The game has already ended.");
        _;
    }

    constructor(uint256 _numToWin) {
        contractOwner = msg.sender;
        numToWin = _numToWin;
    }

    // Player 1 creates the game and places a bet
    function createGame() external payable returns (uint256) {
        require(msg.value > 0, "Bet amount must be greater than zero.");
        require(
            gameCounter == 0 || games[gameCounter].gameEnded,
            "Cannot create a new game while the previous game is unfinished."
        );

        gameCounter++;

        Game storage newGame = games[gameCounter];
        newGame.player1 = Player({
            playerAddress: msg.sender,
            choice: Choice.NONE,
            winCount: 0
        });
        newGame.player2 = Player({
            playerAddress: address(0),
            choice: Choice.NONE,
            winCount: 0
        });
        newGame.player1Commitment = bytes32(0);
        newGame.betAmount = msg.value;
        newGame.gameEnded = false;
        newGame.phase = Phase.CREATED;
        newGame.totalBetsOnPlayer1 = 0;
        newGame.totalBetsOnPlayer2 = 0;

        emit GameCreated(gameCounter, msg.sender, msg.value);
        newGame.phase = Phase.BETTING;
        return gameCounter;
    }

    // External bettors can place bets during the betting phase
    function placeBet(uint256 gameId, bool betOnPlayer1) external payable {
        Game storage game = games[gameId];
        require(
            game.phase == Phase.BETTING,
            "Betting is not allowed at this phase."
        );
        require(msg.value > 0, "Bet amount must be greater than zero.");
        require(
            msg.sender != game.player1.playerAddress &&
                msg.sender != game.player2.playerAddress,
            "Players cannot bet."
        );
        require(
            game.bettors[msg.sender].amount == 0,
            "You have already placed a bet."
        );

        if (betOnPlayer1) {
            game.totalBetsOnPlayer1 += msg.value;
        } else {
            game.totalBetsOnPlayer2 += msg.value;
        }

        game.bettors[msg.sender] = Bettor({
            bettorAddress: msg.sender,
            amount: msg.value,
            betOnPlayer1: betOnPlayer1
        });

        emit BetPlaced(gameId, msg.sender, msg.value, betOnPlayer1);
    }

    // Player 1 commits to a choice (without revealing it)
    function commitChoice(bytes32 _commitment)
        external
        onlyPlayer1
        gameNotEnded
    {
        Game storage game = games[gameCounter];
        require(
            game.phase == Phase.PLAYER1_COMMIT || game.phase == Phase.BETTING,
            "Not the correct phase for committing."
        );
        require(
            game.player1.choice == Choice.NONE,
            "Player 1 has already committed."
        );
        require(
            game.player1Commitment == bytes32(0),
            "Player 1 has already committed."
        );
        game.player1Commitment = _commitment;

        game.phase = Phase.PLAYER2_MOVE;
        emit Player1Committed(gameCounter);
    }

    function generateCommitment(Choice _choice, string memory _secret)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_choice, _secret));
    }

    // Player 2 joins the game and matches the bet
    function joinGame() external payable gameNotEnded {
        Game storage game = games[gameCounter];
        require(
            game.phase == Phase.BETTING ||
                game.phase == Phase.PLAYER1_COMMIT ||
                game.phase == Phase.PLAYER2_MOVE,
            "Player 2 can only join during the BETTING phase."
        );
        require(
            game.player2.playerAddress == address(0),
            "Player 2 has already joined."
        );
        require(
            msg.sender != game.player1.playerAddress,
            "Player 1 cannot join as Player 2."
        );
        require(
            msg.value == game.betAmount,
            "Bet amount must match Player 1's bet."
        );

        game.player2 = Player({
            playerAddress: msg.sender,
            choice: Choice.NONE,
            winCount: 0
        });

        emit Player2Joined(gameCounter, msg.sender);
    }

    // Player 2 makes their choice (ROCK, PAPER, or SCISSORS)
    function player2Play(Choice _choice) external onlyPlayer2 gameNotEnded {
        Game storage game = games[gameCounter];
        require(
            game.phase == Phase.PLAYER2_MOVE,
            "Not the correct phase for Player 2's move."
        );
        require(
            _choice == Choice.ROCK ||
                _choice == Choice.PAPER ||
                _choice == Choice.SCISSORS,
            "Invalid choice."
        );
        game.player2.choice = _choice;

        game.phase = Phase.PLAYER1_REVEAL;
    }

    // Player 1 reveals their choice and ends the round
    function reveal(Choice _choice, string memory _secret)
        external
        onlyPlayer1
        gameNotEnded
    {
        Game storage game = games[gameCounter];
        require(
            game.phase == Phase.PLAYER1_REVEAL,
            "Not the correct phase for revealing."
        );
        require(
            keccak256(abi.encodePacked(_choice, _secret)) ==
                game.player1Commitment,
            "Invalid choice or secret."
        );
        require(
            _choice == Choice.ROCK ||
                _choice == Choice.PAPER ||
                _choice == Choice.SCISSORS,
            "Invalid choice."
        );

        game.player1.choice = _choice;

        emit Player1Revealed(gameCounter, _choice);
        endRound(gameCounter);
    }

    // Ends the round, determines the winner, and checks for match victory
    function endRound(uint256 gameId) internal {
        Game storage game = games[gameId];

        uint8 player1Choice = uint8(game.player1.choice);
        uint8 player2Choice = uint8(game.player2.choice);

        string memory result;
        if (player1Choice == player2Choice) {
            result = "It's a draw!";
        } else if ((player1Choice + 1) % 3 == player2Choice) {
            game.player2.winCount++;
            result = "Player 2 wins this round!";
        } else {
            game.player1.winCount++;
            result = "Player 1 wins this round!";
        }

        emit GameRoundEnded(gameId, result);

        // Reset choices for next round
        game.player1Commitment = bytes32(0);
        game.player1.choice = Choice.NONE;
        game.player2.choice = Choice.NONE;

        // Check if either player has won the match
        if (game.player1.winCount == numToWin) {
            endMatch(gameId, game.player1.playerAddress);
        } else if (game.player2.winCount == numToWin) {
            endMatch(gameId, game.player2.playerAddress);
        } else {
            game.phase = Phase.PLAYER1_COMMIT;
        }
    }

    // Ends the match and transfers the winnings
    function endMatch(uint256 gameId, address winner) internal {
        Game storage game = games[gameId];
        game.gameEnded = true;
        game.phase = Phase.ENDED;

        uint256 totalWinnings = 2 * game.betAmount;
        uint256 winnerShare = (totalWinnings * 95) / 100;
        uint256 ownerShare = totalWinnings - winnerShare;

        payable(winner).transfer(winnerShare);
        payable(contractOwner).transfer(ownerShare);

        emit MatchEnded(gameId, winner, winnerShare);
        emit OwnerFeeTransferred(gameId, contractOwner, ownerShare);

        distributeBettorWinnings(gameId, winner);
    }

    // Distributes winnings to bettors based on the outcome
    function distributeBettorWinnings(uint256 gameId, address winner) internal {
        Game storage game = games[gameId];
        uint256 totalWinningPool = winner == game.player1.playerAddress
            ? game.totalBetsOnPlayer1
            : game.totalBetsOnPlayer2;
        uint256 totalLosingPool = winner == game.player1.playerAddress
            ? game.totalBetsOnPlayer2
            : game.totalBetsOnPlayer1;

        if (totalWinningPool > 0 && totalLosingPool > 0) {
            // Loop through all bettors and distribute winnings
            for (uint256 i = 0; i < totalWinningPool; i++) {
                Bettor storage bettor = game.bettors[msg.sender];
                if (
                    (bettor.betOnPlayer1 &&
                        winner == game.player1.playerAddress) ||
                    (!bettor.betOnPlayer1 &&
                        winner == game.player2.playerAddress)
                ) {
                    uint256 bettorShare = (bettor.amount * totalLosingPool) /
                        totalWinningPool;
                    payable(bettor.bettorAddress).transfer(
                        bettor.amount + bettorShare
                    );
                    emit BettorWinningsTransferred(
                        gameId,
                        bettor.bettorAddress,
                        bettor.amount + bettorShare
                    );
                }
            }
        }
    }

    // Player 1 can get the commitment they made for verification
    function getCommitment() external view returns (bytes32) {
        return games[gameCounter].player1Commitment;
    }
}
