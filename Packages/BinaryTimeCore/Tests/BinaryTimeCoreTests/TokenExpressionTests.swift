import Foundation
import XCTest
@testable import BinaryTimeCore

final class TokenExpressionTests: XCTestCase {
    let screen = ExpressionEnvironment(width: 1440, height: 900, fontSize: 13.05)

    func testClampWithContainerUnits() throws {
        let pad = try TokenExpression("clamp(16px, 4.2cqmin, 64px)")
        XCTAssertEqual(try pad.evaluate(in: screen), 37.8, accuracy: 1e-9)
        XCTAssertEqual(try pad.evaluate(in: ExpressionEnvironment(width: 300, height: 300)), 16)
        XCTAssertEqual(try pad.evaluate(in: ExpressionEnvironment(width: 5000, height: 3000)), 64)
    }

    func testEmAndPercentUnits() throws {
        XCTAssertEqual(try TokenExpression("1.5em").evaluate(in: screen), 19.575, accuracy: 1e-9)
        XCTAssertEqual(try TokenExpression("0.82em").evaluate(in: ExpressionEnvironment(width: 1, height: 1, fontSize: 100)), 82, accuracy: 1e-9)
        XCTAssertEqual(try TokenExpression("50%").evaluate(in: screen), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try TokenExpression("24px").evaluate(in: screen), 24)
        XCTAssertEqual(try TokenExpression("10.4").evaluate(in: screen), 10.4)
    }

    func testVariablesPrecedenceAndParentheses() throws {
        var env = screen
        env.variables = ["pad": 37.8, "gap": 12.6, "labelCol": 172.8, "decimalCol": 129.6, "w": 11]
        let wide = try TokenExpression("min((100cqw - 2*pad - labelCol - decimalCol - (w + 1)*gap) / w, (100cqh - 2*pad - 30cqh) / 10.4, 116px)")
        // (1440 − 75.6 − 172.8 − 129.6 − 151.2) / 11 = 82.8; (900 − 75.6 − 270) / 10.4 = 53.307…
        XCTAssertEqual(try wide.evaluate(in: env), 554.4 / 10.4, accuracy: 1e-9)
        XCTAssertEqual(try TokenExpression("2 + 3 * 4").evaluate(in: env), 14)
        XCTAssertEqual(try TokenExpression("(2 + 3) * 4").evaluate(in: env), 20)
        XCTAssertEqual(try TokenExpression("-w + 1").evaluate(in: env), -10)
        XCTAssertEqual(try TokenExpression("w * -2").evaluate(in: env), -22)
        env.variables["b"] = 50
        XCTAssertEqual(try TokenExpression("min(b * 0.62, 2.4em)").evaluate(in: env), 31, accuracy: 1e-9)
        XCTAssertEqual(try TokenExpression("max(2px, b * 0.12)").evaluate(in: env), 6, accuracy: 1e-9)
        XCTAssertEqual(try TokenExpression("clamp(9px, b * 0.2, 15px)").evaluate(in: env), 10, accuracy: 1e-9)
    }

    func testCSSClampWhenMinExceedsMax() throws {
        XCTAssertEqual(try TokenExpression("clamp(10, 5, 2)").evaluate(in: screen), 10)
    }

    func testErrors() {
        XCTAssertThrowsError(try TokenExpression("clamp(1, 2)").evaluate(in: screen))
        XCTAssertThrowsError(try TokenExpression("foo(1)").evaluate(in: screen))
        XCTAssertThrowsError(try TokenExpression("1 +"))
        XCTAssertThrowsError(try TokenExpression("(1 + 2"))
        XCTAssertThrowsError(try TokenExpression("1 ) 2"))
        XCTAssertThrowsError(try TokenExpression("3vw").evaluate(in: screen))
        XCTAssertThrowsError(try TokenExpression("b * 2").evaluate(in: screen), "Unknown variable")
        XCTAssertThrowsError(try TokenExpression("1 # 2"))
    }

    func testEveryFormulaInTokensParses() {
        // Loading already parsed them; make sure the ones we rely on evaluate for a tiny and a huge screen.
        let tokens = Fixtures.tokens
        for (w, h) in [(320.0, 200.0), (390.0, 844.0), (1440.0, 900.0), (3440.0, 1440.0), (900.0, 1600.0), (7680.0, 4320.0)] {
            for columns in [7, 11, 12, 13, 14] {
                XCTAssertNoThrow(try LayoutMetrics.compute(width: w, height: h, columns: columns, tokens: tokens), "\(w)×\(h) w=\(columns)")
            }
        }
    }
}
