const std = @import("std");

pub const Cell = enum {
    empty,
    black,
    white,
};

pub const Board = [15][15]Cell;

pub const Gomoku = struct {
    board: Board,
    current_player: Cell,
    winner: ?Cell,

    pub fn init() Gomoku {
        var board: Board = undefined;
        for (&board) |*row| {
            for (row) |*cell| {
                cell.* = .empty;
            }
        }
        return Gomoku{
            .board = board,
            .current_player = .black,
            .winner = null,
        };
    }

    pub fn check_win(g: *Gomoku, r: usize, c: usize) void {
        const player = g.board[r][c];
        if (player == .empty) return;

        // horizontal
        var count: usize = 1;
        var i: usize = 1;
        while (c + i < 15 and g.board[r][c + i] == player) : (i += 1) {
            count += 1;
        }
        i = 1;
        while (c >= i and g.board[r][c - i] == player) : (i += 1) {
            count += 1;
        }
        if (count >= 5) {
            g.winner = player;
            return;
        }

        // vertical
        count = 1;
        i = 1;
        while (r + i < 15 and g.board[r + i][c] == player) : (i += 1) {
            count += 1;
        }
        i = 1;
        while (r >= i and g.board[r - i][c] == player) : (i += 1) {
            count += 1;
        }
        if (count >= 5) {
            g.winner = player;
            return;
        }

        // diagonal (top-left to bottom-right)
        count = 1;
        i = 1;
        while (r + i < 15 and c + i < 15 and g.board[r + i][c + i] == player) : (i += 1) {
            count += 1;
        }
        i = 1;
        while (r >= i and c >= i and g.board[r - i][c - i] == player) : (i += 1) {
            count += 1;
        }
        if (count >= 5) {
            g.winner = player;
            return;
        }

        // diagonal (top-right to bottom-left)
        count = 1;
        i = 1;
        while (r + i < 15 and c >= i and g.board[r + i][c - i] == player) : (i += 1) {
            count += 1;
        }
        i = 1;
        while (r >= i and c + i < 15 and g.board[r - i][c + i] == player) : (i += 1) {
            count += 1;
        }
        if (count >= 5) {
            g.winner = player;
            return;
        }
    }
};
