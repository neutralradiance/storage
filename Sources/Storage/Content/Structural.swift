// MARK: Types that form the structure of content
public struct Folder
<ID: LosslessStringConvertible, Structure: Content>: RecursiveContent {
 public var _reflection: Reflection?
 public var _traits: Traits = .directory
 public var _attributes: Attributes = .defaultValue
 public let id: ID
 public let contents: () -> Structure
 public var _contents: [SomeContent] {
  ignoreContent {
   let contents = contents()
   return (contents is [[SomeContent]] ?
    (contents as! [[SomeContent]]).flatMap { $0 } : contents as! [SomeContent])
    .map { $0.merge(with: self) }
  }
 }

 public init(_ name: ID, @Storage.Contents contents: @escaping () -> Structure) {
  self.id = name
  self.contents = contents
 }
}

public extension Folder where ID == String {
 init<Element>(
  _ element: Element, id: KeyPath<Element, some LosslessStringConvertible>,
  @Storage.Contents contents: @escaping () -> Structure
 ) {
  self.id = element[keyPath: id].description
  self.contents = contents
 }

 init<Element: Identifiable>(
  _ element: Element, @Storage.Contents contents: @escaping () -> Structure
 ) where Element.ID: LosslessStringConvertible {
  self.id = element.id.description
  self.contents = contents
 }
}

extension Folder where Structure == EmptyContent {
 init(_ name: ID) {
  self.id = name
  self.contents = { EmptyContent() }
 }
}

/// Forms variadic content that can be modified to as a result of the closure
/// Contents within the closure are bound by the offset of the element
/// and compared by the specific indicator that conforms to hashable
/// Traits and attributes applied to a `ForEach` structure should merge with
/// the result of the closure
/// To translate a property wrapper from another framework, an observable
/// key path to the elements must be accessed
public struct ForEach<Elements: RandomAccessCollection>: VariadicContent {
 public var _reflection: Reflection?
 public var _traits: Traits = .variadic
 public var _attributes: Attributes = .defaultValue
 /// Elements that should update the content result when changed
 /// This requires a publisher state compatible property wrapper
 public var elements: Elements
 public let result: (Elements.Element) -> SomeContent
 /// The hash value used to compare values
 public let keyPath: KeyPath<Elements.Element, AnyHashable>
 public var _contents: [SomeContent] {
  ignoreContent {
   elements.map { element in
    result(element).merge(with: self)
   }
  }
 }

 public init(
  _ elements: Elements,
  @Storage.Contents result: @escaping (Elements.Element) -> some Content
 ) where Elements.Element: Hashable {
  self.elements = elements
  self.keyPath = \Elements.Element.erasedToAny
  self.result = result
 }
}

public extension ForEach {
 init(
  _ elements: Elements, id: KeyPath<Elements.Element, some Hashable>,
  @Storage.Contents result: @escaping (Elements.Element) -> some Content
 ) {
  self.elements = elements
  self.keyPath = id.appending(path: \.erasedToAny)
  self.result = result
 }
}

extension ForEach where Elements.Element: Identifiable {
 init(
  _ elements: Elements,
  @Storage.Contents identifying: @escaping (Elements.Element) -> some Content
 ) {
  self.elements = elements
  self.keyPath = \Elements.Element.id.erasedToAny
  self.result = identifying
 }
}

// Applies modifiers from the group to the contents of the closure
public struct Group<Contents: Content>: VariadicContent {
 public var _reflection: Reflection?
 public var _traits: Traits = .variadic
 public var _attributes: Attributes = .defaultValue
 public let contents: () -> Contents
 public var _contents: [SomeContent] {
  ignoreContent { contents() as! [SomeContent] }
 }

 public init(@Storage.Contents contents: @escaping () -> Contents) {
  self.contents = contents
 }
}

// MARK: Extensions
public extension Traits {
 static var variadic: Self {
  var `self`: Self = .defaultValue
  self.isObservable = false
  return self
 }

 static var recursive: Self {
  var `self`: Self = .variadic
  self.isRecursive = true
  return self
 }

 static var directory: Self {
  var `self`: Self = .recursive
  self.contentType = .folder
  return self
 }
}

/// - Note: Create unambiguous descriptions
/// path based descriptions shouldn't be ambiguous
/// so the parser must form the paths so they are less indistiguishable
extension Hashable {
 var erasedToAny: AnyHashable { AnyHashable(self) }
}

extension Content {
 @inlinable func merge(with content: some DynamicContent) -> Self {
  var copy = self
  copy._traits.merge(with: content._traits)
  if var dynamic = copy as? any DynamicContent {
   dynamic._attributes.merge(with: content._attributes)
   copy = dynamic as! Self
  }
  return copy
 }
}
