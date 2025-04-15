/*
# How Swift Result Builders Work

Result builders transform the code inside their closures into a series of method calls
on the result builder type. Understanding this transformation helps when debugging or
extending the DSL.

## DSL Code Transformation

When you write:

```swift
let sequence = WaveformBuilder {
    Sine()
    EaseOut(3.0)
    Phase(0.2)
}
```

The Swift compiler transforms this to:

```swift
let sequence = {
    let _a = Sine()                 // Component 1
    let _b = EaseOut(3.0)           // Component 2
    let _c = Phase(0.2)             // Component 3
    
    let _r1 = WaveformBuilder.buildBlock(_a)
    let _r2 = WaveformBuilder.buildBlock(_r1, _b)
    let _r3 = WaveformBuilder.buildBlock(_r2, _c)
    
    return WaveformBuilder.buildFinalResult(_r3)
}()
```

However, for our implementation, we defined our `buildBlock` method to accept multiple
components at once, so the actual transformation is more like:

```swift
let sequence = {
    let _a = Sine()                 // Component 1
    let _b = EaseOut(3.0)           // Component 2
    let _c = Phase(0.2)             // Component 3
    
    let _r = WaveformBuilder.buildBlock(_a, _b, _c)
    
    return WaveformBuilder.buildFinalResult(_r)
}()
```

## Result Builder Methods

The `@resultBuilder` attribute enables this transformation by defining methods that
the compiler calls during the transformation:

- `buildBlock`: Combines components into a single result
- `buildOptional`: Handles optional components (if statements with no else)
- `buildEither(first:)`: Handles the 'then' branch of if-else
- `buildEither(second:)`: Handles the 'else' branch of if-else
- `buildArray`: Handles arrays of components (for loops)
- `buildExpression`: Transforms each expression before further processing
- `buildFinalResult`: Performs final transformations on the result
*/

// MARK: - Result Builder Methods Explained

import Foundation

// Simplified example showing how each result builder method works
@resultBuilder
struct SimplifiedBuilder {
    
    // MARK: buildBlock
    
    // This method combines components into a single result
    // It's called for every statement group in the closure
    static func buildBlock(_ components: String...) -> String {
        return components.joined(separator: " + ")
    }
    
    // MARK: buildOptional
    
    // This method handles if statements with no else
    static func buildOptional(_ component: String?) -> String {
        return component ?? "Empty"
    }
    
    // MARK: buildEither
    
    // These methods handle if-else statements
    static func buildEither(first component: String) -> String {
        return "If: " + component
    }
    
    static func buildEither(second component: String) -> String {
        return "Else: " + component
    }
    
    // MARK: buildArray
    
    // This method handles arrays (for loops)
    static func buildArray(_ components: [String]) -> String {
        return "[\(components.joined(separator: ", "))]"
    }
    
    // MARK: buildExpression
    
    // This method transforms each expression before further processing
    static func buildExpression(_ expression: Int) -> String {
        return "Number(\(expression))"
    }
    
    static func buildExpression(_ expression: String) -> String {
        return "Text(\(expression))"
    }
    
    // MARK: buildFinalResult
    
    // This method performs final transformations on the result
    static func buildFinalResult(_ component: String) -> String {
        return "Result: " + component
    }
}

// MARK: - Simple DSL Usage Examples

class ResultBuilderExamples {
    
    // Using the simplified builder
    func simpleDSLExample() -> String {
        // This will be transformed by the result builder
        @SimplifiedBuilder
        func buildString() -> String {
            "Hello"
            "World"
            42
            
            if Bool.random() {
                "Condition true"
            }
            
            if Bool.random() {
                "If branch"
            } else {
                "Else branch"
            }
            
            for i in 1...3 {
                "Item \(i)"
            }
        }
        
        return buildString()
    }
    
    // How the code is transformed
    func manualTransformation() -> String {
        // This shows what the compiler does with the DSL code
        let result1 = SimplifiedBuilder.buildExpression("Hello")
        let result2 = SimplifiedBuilder.buildExpression("World") 
        let result3 = SimplifiedBuilder.buildExpression(42)
        
        let combined = SimplifiedBuilder.buildBlock(result1, result2, result3)
        
        // Handle optional
        let condition = Bool.random()
        let conditionalResult: String?
        if condition {
            conditionalResult = SimplifiedBuilder.buildExpression("Condition true")
        } else {
            conditionalResult = nil
        }
        let optionalResult = SimplifiedBuilder.buildOptional(conditionalResult)
        
        // Handle if-else
        let ifElseCondition = Bool.random()
        let ifElseResult: String
        if ifElseCondition {
            let ifBranch = SimplifiedBuilder.buildExpression("If branch")
            ifElseResult = SimplifiedBuilder.buildEither(first: ifBranch)
        } else {
            let elseBranch = SimplifiedBuilder.buildExpression("Else branch")
            ifElseResult = SimplifiedBuilder.buildEither(second: elseBranch)
        }
        
        // Handle array (for loop)
        var arrayComponents: [String] = []
        for i in 1...3 {
            let item = SimplifiedBuilder.buildExpression("Item \(i)")
            arrayComponents.append(item)
        }
        let arrayResult = SimplifiedBuilder.buildArray(arrayComponents)
        
        // Combine all the components
        let finalComponent = SimplifiedBuilder.buildBlock(
            combined, optionalResult, ifElseResult, arrayResult
        )
        
        // Apply final transformation
        return SimplifiedBuilder.buildFinalResult(finalComponent)
    }
}

// MARK: - WaveformBuilder Implementation Details

/*
## Implementation Details of WaveformBuilder

Our WaveformBuilder transforms the code into method calls that create a chain of
WaveformNode objects, which ultimately create a FloatOp function.

The key parts are:

1. Each component creates a WaveformNode object
2. buildBlock combines multiple nodes into a ChainNode
3. buildFinalResult converts the final node to a FloatOp

### Execution Flow

1. Each expression creates a WaveformNode (Sine(), EaseOut(3.0), etc.)
2. buildBlock combines them into a ChainNode
3. buildFinalResult calls createOperation() on the final node
4. The result is a FloatOp function ready to use

This approach creates a lightweight syntax that reads naturally while
maintaining type safety and performance.
*/

// MARK: - Custom Result Builder Usage

// Define a simple operation that computes a value
typealias Operation = (Float) -> Float

// Custom result builder for mathematical expressions
@resultBuilder
struct MathBuilder {
    static func buildBlock(_ components: Operation...) -> Operation {
        return { x in
            var result: Float = x
            for op in components {
                result = op(result)
            }
            return result
        }
    }
    
    static func buildExpression(_ expression: @escaping Operation) -> Operation {
        return expression
    }
    
    static func buildExpression(_ value: Float) -> Operation {
        return { _ in value }
    }
}

// Define operations
func add(_ value: Float) -> Operation {
    return { x in x + value }
}

func multiply(_ value: Float) -> Operation {
    return { x in x * value }
}

func square() -> Operation {
    return { x in x * x }
}

// Use the math builder
@MathBuilder
func computeValue(x: Float) -> Operation {
    add(10)
    multiply(2)
    square()
    add(5)
}

// Usage
func mathExample() {
    let operation = computeValue(x: 0)
    let result = operation(3) // Computes (((3 + 10) * 2)^2 + 5) = 53 + 5 = 58
    print("Result: \(result)")
}

// MARK: - Advanced Result Builder Techniques

/*
## Advanced Techniques

### 1. Nested Builders

Result builders can be nested within each other to create complex hierarchical structures:

```swift
WaveformBuilder {
    Sine()
    
    // Nested modulation chain
    WaveformBuilder {
        Triangle()
        Rate(0.5)
    }
}
```

### 2. Generic Result Builders

Result builders can be made generic to work with different component types:

```swift
@resultBuilder
struct GenericBuilder<T> {
    static func buildBlock(_ components: T...) -> [T] {
        return components
    }
}
```

### 3. Context-Aware Builders

Result builders can capture context information:

```swift
@resultBuilder
struct ContextAwareBuilder {
    struct Context {
        var depth: Int = 0
    }
    
    static func buildBlock(_ context: inout Context, _ components: String...) -> String {
        return String(repeating: "  ", count: context.depth) + components.joined()
    }
}
```

### 4. Conditional Result Builders

Result builders can adjust behavior based on conditions:

```swift
@resultBuilder
struct ConditionalBuilder {
    static func buildBlock<T>(_ components: T...) -> [T] {
        return components
    }
    
    static func buildEither<T>(first component: T) -> T where T: Collection {
        return component
    }
    
    static func buildEither<T>(second component: T) -> T where T: Collection {
        return component
    }
}
```
*/

// MARK: - DSL vs Traditional API Performance

/*
## Performance Considerations

The DSL approach might appear to add overhead due to the creation of intermediate
objects, but in practice:

1. The Swift compiler performs optimizations that eliminate most intermediate objects
2. The final code operates on function pointers, which are very efficient
3. All DSL construction happens at compile time or during initialization, not during the 
   performance-critical signal generation phase

In our benchmarks, the DSL vs. traditional API showed negligible differences
in performance for the final signal generation, while significantly improving
code readability and maintainability.
*/

// MARK: - Debugging DSL Code

/*
## Debugging DSL Code

When debugging issues with DSL code:

1. Break down complex expressions into smaller parts to isolate issues
2. Use explicit type annotations to verify correct types
3. Create standalone components for complex parts
4. Check that your result builder methods handle edge cases properly

For example, instead of:

```swift
let complexWave = WaveformBuilder {
    Sine()
    Ring(
        IdentityNode(),
        Triangle().rate(0.25).bias(0.5)
    )
    EaseOut(2.0)
}
```

Break it down:

```swift
let modulator: WaveformNode = Triangle().rate(0.25).bias(0.5)
let ringMod: WaveformNode = Ring(IdentityNode(), modulator)

let complexWave = WaveformBuilder {
    Sine()
    ringMod
    EaseOut(2.0)
}
```

This makes it easier to debug each component independently.
*/
