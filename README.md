\section*{How to Use}

\begin{enumerate}
    \item Please note that we use $0$ to represent Rock, $1$ to represent Paper, and $2$ to represent Scissors. Input $1, 2, 3$ as your choice instead of a string. \newline

    \item \textbf{Reveal Scheme:}
    \begin{enumerate}
        \item When deploying, we are asked to provide a value \texttt{numToWin} to represent the number of games you need to win to claim the whole game. Call \texttt{generateCommitment} (Example: Choice: 1, Secret: "a"). Obtain your commitment (this is usually done offline, but we provide a one-stop solution for easier testing). \newline

        \item Switch to another account to test Bonus Question 1. Set a bid value (Example: 10 ethers). Then call \texttt{createGame}. \newline

        \item Call \texttt{c
