//
//  LinkedList.swift
//  trailer
//
//  Created by Paul Tsochantaris on 07/01/2023.
//

import Foundation

final class LinkedList<Value>: Sequence {
    final class Node<Value> {
        fileprivate let value: Value
        fileprivate var next: Node<Value>?

        init(_ value: Value, _ next: Node<Value>?) {
            self.value = value
            self.next = next
        }
    }

    private var head: Node<Value>?
    private var tail: Node<Value>?

    var count: Int

    init(value: Value? = nil) {
        if let value {
            let node = Node(value, nil)
            head = node
            tail = node
            count = 1
        } else {
            head = nil
            tail = nil
            count = 0
        }
    }

    func push(_ value: Value) {
        count += 1

        if head == nil {
            let newNode = Node(value, nil)
            head = newNode
            tail = newNode
        } else {
            head = Node(value, head)
        }
    }

    func pop() -> Value? {
        if let top = head {
            head = top.next
            count -= 1
            return top.value
        } else {
            return nil
        }
    }

    func removeAll() {
        head = nil
        tail = nil
        count = 0
    }

    final class ListIterator: IteratorProtocol {
        private var current: Node<Value>?

        fileprivate init(_ current: Node<Value>?) {
            self.current = current
        }

        func next() -> Value? {
            if let res = current {
                current = res.next
                return res.value
            } else {
                return nil
            }
        }
    }

    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> ListIterator {
        ListIterator(head)
    }

    var underestimatedCount: Int { count }

    func withContiguousStorageIfAvailable<R>(_: (_ buffer: UnsafeBufferPointer<Value>) throws -> R) rethrows -> R? { nil }
}
