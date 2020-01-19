import UIKit
import PlaygroundSupport

// Operators /////////////////////////////////////////////////////////

precedencegroup CompositionPrecedence {
    associativity: right
}

infix operator • : CompositionPrecedence

func • <A, B, C>(f : @escaping (B) -> C, g : @escaping (A) -> B) -> (A) -> C { { f(g($0)) } }

// Lib ///////////////////////////////////////////////////////////////

func head<A>(_ xs: [A]) -> A { xs.first! }

func tail<A>(_ xs: [A]) -> [A] { [A](xs.dropFirst()) }

func map<A, B>(_ f: @escaping (A) -> B) -> ([A]) -> [B] { { $0.map(f) } }

func randomElement<A>(_ xs: [A]) -> A? { xs.randomElement() }

func transpose<A>(_ xss: [[A]]) -> [[A]] {
    switch (xss.first?.count) {
    case 0: return [[A]]()
    case _: return [xss.map(head)] + transpose(xss.map(tail))
    }
}

// Game //////////////////////////////////////////////////////////////

typealias Row = [Int]
typealias Board = [Row]

let emptyRow = { Row(repeating: 0, count: $0) }
let emptyBoard = { Board(repeating: emptyRow($0), count: $1) }

func fuseLeft(_ xs: Row) -> Row {
    switch (xs.first, xs.dropFirst().first, Row(xs.dropFirst(2))) {
    case let (.some(0), .some(b), tail):              return fuseLeft([b] + tail) + [0]
    case let (.some(a), .some(0), tail):              return fuseLeft([a] + tail) + [0]
    case let (.some(a), .some(b), tail) where a == b: return [a+1] + fuseLeft(tail) + [0]
    case let (.some(a), .some(b), tail):              return [a] + fuseLeft([b] + tail)
    case _:                                           return xs
    }
}

let fuseBoard = map(fuseLeft)
let flipH: (Board) -> Board = map { $0.reversed() }

let moveLeft = fuseBoard
let moveRight = flipH • fuseBoard • flipH
let moveUp = transpose • fuseBoard • transpose
let moveDown = transpose • flipH • fuseBoard • flipH • transpose
let set: (Int, Int) -> (Int) -> (Board) -> Board = { i, j in { v in { var b = $0; b[i][j] = v; return b } } }

func emptyCells(_ board: Board) -> [(Int, Int)] {
    board.enumerated().flatMap { i, row in
        row.enumerated().compactMap { j, value in
            value == 0 ? (i, j) : nil
        }
    }
}

let randomEmptyCell = randomElement • emptyCells

func randomInt() -> Int { Int.random(in: (9...18)) / 9 }

func compMove(_ board: Board) -> Board {
    randomEmptyCell(board).map { set($0, $1)(randomInt())(board) } ?? board
}

let start = compMove • compMove • emptyBoard

// UI ////////////////////////////////////////////////////////////////

extension UIColor {
    static let bg = #colorLiteral(red: 0.7333333333, green: 0.6784313725, blue: 0.6235294118, alpha: 1)
    private static let font = [#colorLiteral(red: 0.462745098, green: 0.431372549, blue: 0.4, alpha: 1), #colorLiteral(red: 0.462745098, green: 0.431372549, blue: 0.4, alpha: 1), #colorLiteral(red: 0.9764705882, green: 0.9647058824, blue: 0.9490196078, alpha: 1)]
    private static let cell = [#colorLiteral(red: 0.8, green: 0.7568627451, blue: 0.7058823529, alpha: 1), #colorLiteral(red: 0.9333333333, green: 0.8941176471, blue: 0.8549019608, alpha: 1) ,#colorLiteral(red: 0.9294117647, green: 0.8784313725, blue: 0.7843137255, alpha: 1) ,#colorLiteral(red: 0.9490196078, green: 0.6941176471, blue: 0.4745098039, alpha: 1) ,#colorLiteral(red: 0.9607843137, green: 0.5843137255, blue: 0.3882352941, alpha: 1), #colorLiteral(red: 0.9647058824, green: 0.4862745098, blue: 0.3725490196, alpha: 1), #colorLiteral(red: 0.9647058824, green: 0.368627451, blue: 0.231372549, alpha: 1), #colorLiteral(red: 0.9294117647, green: 0.8117647059, blue: 0.4470588235, alpha: 1), #colorLiteral(red: 0.9294117647, green: 0.8, blue: 0.3803921569, alpha: 1), #colorLiteral(red: 0.9294117647, green: 0.7843137255, blue: 0.3137254902, alpha: 1), #colorLiteral(red: 0.9294117647, green: 0.7725490196, blue: 0.2470588235, alpha: 1), #colorLiteral(red: 0.9294117647, green: 0.7607843137, blue: 0.1803921569, alpha: 1), #colorLiteral(red: 0.2352941176, green: 0.2274509804, blue: 0.1960784314, alpha: 1)]
    static func font(_ i: Int) -> UIColor { font[i < font.count ? i : font.count - 1] }
    static func cell(_ i: Int) -> UIColor { cell[i < cell.count ? i : cell.count - 1] }
}

class Swiper: UISwipeGestureRecognizer {
    var closure = { }
    @objc func action() { closure() }
    init(_ direction: Direction, _ closure: @escaping () -> ()) {
        super.init(target: nil, action: nil)
        self.direction = direction
        self.addTarget(self, action: #selector(action))
        self.closure = closure
    }
}

class GameView: UIView {

    let cells: [[UILabel]]
    var board: Board { didSet { renderBoard() } }

    init(n: Int, m: Int, frame: CGRect) {
        self.board = start((n, m))
        let cellWidth = frame.width / CGFloat(m)
        let cellHeight = frame.height / CGFloat(n)
        self.cells = (0..<m).map { m in
            (0..<n).map { n in
                let cell = UILabel(frame: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight)
                    .offsetBy(dx: cellWidth * CGFloat(m), dy: cellHeight * CGFloat(n))
                    .insetBy(dx: 5, dy: 5))
                cell.font = UIFont.systemFont(ofSize: 25)
                cell.textAlignment = .center
                return cell
            }
        }
        super.init(frame: frame)
        backgroundColor = .bg
        cells.forEach { $0.forEach { cell in addSubview(cell) } }
        gestureRecognizers = [
            Swiper(.left) { self.makeMove(moveLeft) },
            Swiper(.right) { self.makeMove(moveRight) },
            Swiper(.up) { self.makeMove(moveUp) },
            Swiper(.down) { self.makeMove(moveDown) }
        ]
        renderBoard()
    }

    required init?(coder: NSCoder) { fatalError() }

    func renderBoard() {
        board.enumerated().forEach { j, row in
            row.enumerated().forEach { i, value in
                let cell = cells[i][j]
                cell.backgroundColor = .cell(value)
                cell.text = value > 0 ? "\(pow(2, value))" : nil
                cell.textColor = value > 0 ? .font(value - 1) : nil
            }
        }
    }

    func makeMove(_ move: (Board) -> Board) {
        let newBoard = move(board)
        if board != newBoard { board = compMove(newBoard) }
    }
}

PlaygroundPage.current.liveView = GameView(n: 4, m: 4, frame: CGRect(x: 0, y: 0, width: 300, height: 300))
