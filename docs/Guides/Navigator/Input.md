# Observing user input

In visual publications like EPUB or PDF, users can interact with the `VisualNavigator` instance using gestures, a keyboard, a mouse, a pencil, or a trackpad. When the publication does not override user input events, you may want to intercept them to trigger actions in your user interface. For example, you can turn pages or toggle the navigation bar on taps, or open a bookmarks screen when pressing the Command-Shift-D hotkey.

`VisualNavigator` implements `InputObservable`, providing a way to intercept input events.

## Implementing an input observer

Here's an example of a simple `InputObserving` implementation that logs all key and pointer events emitted by the navigator.

```swift
navigator.addObserver(InputObserver())

@MainActor final class InputObserver: InputObserving {
    func didReceive(_ event: PointerEvent) -> Bool {
        print("Received pointer event: \(event)")
        return false
    }
    
    func didReceive(_ event: KeyEvent) -> Bool {
        print("Received key event: \(event)")
        return false
    }
}
```

If you choose to handle a specific event, return `true` to prevent subsequent observers from using it. This is useful when you want to avoid triggering multiple actions upon receiving an event.

An `InputObserving` implementation receives low-level events that can be used to create higher-level gesture recognizers, such as taps or pinches. To assist you, the toolkit also offers helpers to observe tap, click and key press events.

## Observing tap and click events

The `ActivatePointerObserver` is an implementation of `InputObserving` recognizing single taps or clicks. You can use the convenient static factories to observe these events.

```swift
navigator.addObserver(.tap { event in
    print("User tapped at \(event.location)")
    return false
})

// Key modifiers can be used to recognize an event only when a modifier key is pressed.
navigator.addObserver(.click(modifiers: [.shift]) { event in
    print("User clicked at \(event.location)")
    return false
})
```

## Observing keyboard events

Similarly, the `KeyboardObserver` implementation provides an easy method to intercept keyboard events.

```swift
navigator.addObserver(.key { event in
    print("User pressed the key \(event.key) with modifiers \(event.modifiers)")
    return false
})
```

It can also be used to observe a specific keyboard shortcut.

```swift
navigator.addObserver(.key(.a) {
    self.log(.info, "User pressed A")
    return false
})

navigator.addObserver(.key(.a, [.control, .shift]) {
    self.log(.info, "User pressed Control+Shift+A")
    return false
})
```
