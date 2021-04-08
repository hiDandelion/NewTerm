//
//  TerminalKeyInput.swift
//  NewTerm
//
//  Created by Adam Demasi on 10/1/18.
//  Copyright © 2018 HASHBANG Productions. All rights reserved.
//

import UIKit

class TerminalKeyInput: TextInputBase {

	weak var terminalInputDelegate: TerminalInputProtocol?
	weak var textView: UITextView! {
		didSet {
			textView.frame = bounds
			textView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
			insertSubview(textView, at: 0)
		}
	}

	private var toolbar: KeyboardToolbar?

	private let ctrlKey  = KeyboardButton(title: "Control",   glyph: "Ctrl", systemImage: "control", image: UIImage(named: "key-control"))
	private let metaKey  = KeyboardButton(title: "Escape",    glyph: "Esc",  systemImage: "escape", image: UIImage(named: "key-escape"))
	private let tabKey   = KeyboardButton(title: "Tab",       glyph: "Tab",  systemImage: "arrow.right.to.line", image: UIImage(named: "key-tab"))
	private let moreKey  = KeyboardButton(title: "Functions", systemImage: "ellipsis", image: UIImage(named: "key-more"))

	private let upKey    = KeyboardButton(title: "Up",    systemImage: "arrow.up",    image: UIImage(named: "key-up"))
	private let downKey  = KeyboardButton(title: "Down",  systemImage: "arrow.down",  image: UIImage(named: "key-down"))
	private let leftKey  = KeyboardButton(title: "Left",  systemImage: "arrow.left",  image: UIImage(named: "key-left"))
	private let rightKey = KeyboardButton(title: "Right", systemImage: "arrow.right", image: UIImage(named: "key-right"))

	private var longPressTimer: Timer?
	private var buttons: [KeyboardButton]!
	private var squareButtonConstraints: [NSLayoutConstraint]!
	private var moreToolbar = KeyboardPopupToolbar(frame: .zero)
	private var moreToolbarBottomConstraint: NSLayoutConstraint!

	private var ctrlDown = false
	private var previousFloatingCursorPoint: CGPoint? = nil

	private var passwordInputView: TerminalPasswordInputView?

	private let backspaceData   = Data([ 0x7F ]) // \x7F
	private let metaKeyData     = Data([ 0x1B ]) // \e
	private let tabKeyData      = Data([ 0x09 ]) // \t
	private let returnKeyData   = Data([ 0x0D ]) // \r
	private let upKeyData       = Data([ 0x1B, 0x5B, 0x41 ]) // \e[A
	private let upKeyAppData    = Data([ 0x1B, 0x4F, 0x41 ]) // \eOA
	private let downKeyData     = Data([ 0x1B, 0x5B, 0x42 ]) // \e[B
	private let downKeyAppData  = Data([ 0x1B, 0x4F, 0x42 ]) // \eOB
	private let leftKeyData     = Data([ 0x1B, 0x5B, 0x44 ]) // \e[D
	private let leftKeyAppData  = Data([ 0x1B, 0x4F, 0x44 ]) // \eOD
	private let rightKeyData    = Data([ 0x1B, 0x5B, 0x43 ]) // \e[C
	private let rightKeyAppData = Data([ 0x1B, 0x4F, 0x43 ]) // \eOC
	private let homeKeyData     = Data([ 0x1B, 0x5B, 0x48 ]) // \e[H
	private let endKeyData      = Data([ 0x1B, 0x5B, 0x46 ]) // \e[F
	private let pageUpKeyData   = Data([ 0x1B, 0x5B, 0x35, 0x7E ]) // \e[5~
	private let pageDownKeyData = Data([ 0x1B, 0x5B, 0x36, 0x7E ]) // \e[6~
	private let deleteKeyData   = Data([ 0x1B, 0x5B, 0x33, 0x7E ]) // \e[3~

	override init(frame: CGRect) {
		super.init(frame: frame)

		autocapitalizationType = .none
		autocorrectionType = .no
		spellCheckingType = .no
		smartQuotesType = .no
		smartDashesType = .no
		smartInsertDeleteType = .no

		buttons = [
			ctrlKey, metaKey, tabKey, moreKey,
			upKey, downKey, leftKey, rightKey
		]

		if UIDevice.current.userInterfaceIdiom == .pad {
			inputAssistantItem.allowsHidingShortcuts = false

			let xSpacing = CGFloat(6)
			let height = CGFloat(isSmallDevice ? 36 : 44)

			let leftContainerView = UIView()
			leftContainerView.translatesAutoresizingMaskIntoConstraints = false

			let leftSpacerView = UIView()
			leftSpacerView.translatesAutoresizingMaskIntoConstraints = false

			let leftStackView = UIStackView(arrangedSubviews: [ ctrlKey, metaKey, tabKey, moreKey, leftSpacerView ])
			leftStackView.translatesAutoresizingMaskIntoConstraints = false
			leftStackView.axis = .horizontal
			leftStackView.spacing = xSpacing
			leftContainerView.addSubview(leftStackView)

			var leadingBarButtonGroups = inputAssistantItem.leadingBarButtonGroups
			leadingBarButtonGroups.append(UIBarButtonItemGroup(barButtonItems: [
				UIBarButtonItem(customView: leftContainerView)
			], representativeItem: nil))
			inputAssistantItem.leadingBarButtonGroups = leadingBarButtonGroups

			let rightContainerView = UIView()
			rightContainerView.translatesAutoresizingMaskIntoConstraints = false

			let rightSpacerView = UIView()
			rightSpacerView.translatesAutoresizingMaskIntoConstraints = false

			let rightStackView = UIStackView(arrangedSubviews: [ rightSpacerView, upKey, downKey, leftKey, rightKey ])
			rightStackView.translatesAutoresizingMaskIntoConstraints = false
			rightStackView.axis = .horizontal
			rightStackView.spacing = xSpacing
			rightContainerView.addSubview(rightStackView)

			var trailingBarButtonGroups = inputAssistantItem.trailingBarButtonGroups
			trailingBarButtonGroups.append(UIBarButtonItemGroup(barButtonItems: [
				UIBarButtonItem(customView: rightContainerView)
			], representativeItem: nil))
			inputAssistantItem.trailingBarButtonGroups = trailingBarButtonGroups

			NSLayoutConstraint.activate([
				leftStackView.leadingAnchor.constraint(equalTo: leftContainerView.leadingAnchor),
				rightStackView.leadingAnchor.constraint(equalTo: rightContainerView.leadingAnchor),
				leftStackView.trailingAnchor.constraint(equalTo: leftContainerView.trailingAnchor),
				rightStackView.trailingAnchor.constraint(equalTo: rightContainerView.trailingAnchor),
				leftStackView.heightAnchor.constraint(equalToConstant: height),
				rightStackView.heightAnchor.constraint(equalToConstant: height),
				leftStackView.centerYAnchor.constraint(equalTo: leftContainerView.centerYAnchor),
				rightStackView.centerYAnchor.constraint(equalTo: rightContainerView.centerYAnchor)
			])
		} else {
			toolbar = KeyboardToolbar()
			toolbar!.translatesAutoresizingMaskIntoConstraints = false
			toolbar!.ctrlKey = ctrlKey
			toolbar!.metaKey = metaKey
			toolbar!.tabKey = tabKey
			toolbar!.moreKey = moreKey
			toolbar!.upKey = upKey
			toolbar!.downKey = downKey
			toolbar!.leftKey = leftKey
			toolbar!.rightKey = rightKey
			toolbar!.setUp()
		}

		ctrlKey.addTarget(self,  action: #selector(self.ctrlKeyPressed), for: .touchUpInside)
		metaKey.addTarget(self,  action: #selector(self.inputKeyPressed), for: .touchUpInside)
		tabKey.addTarget(self,   action: #selector(self.inputKeyPressed), for: .touchUpInside)
		moreKey.addTarget(self,  action: #selector(self.moreKeyPressed), for: .touchUpInside)
		upKey.addTarget(self,    action: #selector(self.arrowKeyPressed), for: .touchUpInside)
		downKey.addTarget(self,  action: #selector(self.arrowKeyPressed), for: .touchUpInside)
		leftKey.addTarget(self,  action: #selector(self.arrowKeyPressed), for: .touchUpInside)
		rightKey.addTarget(self, action: #selector(self.arrowKeyPressed), for: .touchUpInside)

		moreToolbar.homeKey.addTarget(self,     action: #selector(self.inputKeyPressed), for: .touchUpInside)
		moreToolbar.endKey.addTarget(self,      action: #selector(self.inputKeyPressed), for: .touchUpInside)
		moreToolbar.pageUpKey.addTarget(self,   action: #selector(self.inputKeyPressed), for: .touchUpInside)
		moreToolbar.pageDownKey.addTarget(self, action: #selector(self.inputKeyPressed), for: .touchUpInside)
		moreToolbar.deleteKey.addTarget(self,   action: #selector(self.inputKeyPressed), for: .touchUpInside)

		for key in [ upKey, downKey, leftKey, rightKey ] {
			let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.arrowKeyLongPressed(_:)))
			key.addGestureRecognizer(gestureRecognizer)
		}

		moreToolbarBottomConstraint = moreToolbar.bottomAnchor.constraint(equalTo: self.bottomAnchor)

		setMoreRowVisible(false, animated: false)
		addSubview(moreToolbar)

		NSLayoutConstraint.activate([
			moreToolbar.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			moreToolbar.trailingAnchor.constraint(equalTo: self.trailingAnchor),
			moreToolbarBottomConstraint,

			ctrlKey.widthAnchor.constraint(greaterThanOrEqualTo: metaKey.widthAnchor),
			metaKey.widthAnchor.constraint(greaterThanOrEqualTo: ctrlKey.widthAnchor),
			metaKey.widthAnchor.constraint(greaterThanOrEqualTo: tabKey.widthAnchor),
			tabKey.widthAnchor.constraint(greaterThanOrEqualTo: metaKey.widthAnchor),
			tabKey.widthAnchor.constraint(greaterThanOrEqualTo: moreKey.widthAnchor),
			moreKey.widthAnchor.constraint(greaterThanOrEqualTo: tabKey.widthAnchor)
		])

		NSLayoutConstraint.activate([ upKey, downKey, leftKey, rightKey ].map { view in view.widthAnchor.constraint(equalTo: view.heightAnchor) })
		squareButtonConstraints = [ ctrlKey, metaKey, tabKey, moreKey ].map { view in view.widthAnchor.constraint(equalTo: view.heightAnchor) }

		NotificationCenter.default.addObserver(self, selector: #selector(self.preferencesUpdated), name: Preferences.didChangeNotification, object: nil)
		preferencesUpdated()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override var inputAccessoryView: UIView? {
		return toolbar
	}

	@objc func preferencesUpdated() {
		let preferences = Preferences.shared
		let style = preferences.keyboardAccessoryStyle

		for button in buttons {
			button.style = style
		}

		// Enable 1:1 width:height aspect ratio if using icons style
		switch style {
		case .text:  NSLayoutConstraint.deactivate(squareButtonConstraints)
		case .icons: NSLayoutConstraint.activate(squareButtonConstraints)
		}
	}

	// MARK: - Callbacks

	@objc func ctrlKeyPressed() {
		ctrlDown = !ctrlDown
		ctrlKey.isSelected = ctrlDown
	}

	@objc func ctrlKeyCommandPressed(_ keyCommand: UIKeyCommand) {
		if keyCommand.input != nil {
			ctrlDown = true
			insertText(keyCommand.input!)
		}
	}

	@objc private func inputKeyPressed(_ sender: KeyboardButton) {
		let keyValues: [KeyboardButton: Data] = [
			metaKey:  metaKeyData,
			tabKey:   tabKeyData,
			moreToolbar.homeKey:     homeKeyData,
			moreToolbar.endKey:      endKeyData,
			moreToolbar.pageUpKey:   pageUpKeyData,
			moreToolbar.pageDownKey: pageDownKeyData,
			moreToolbar.deleteKey:   deleteKeyData
		]
		if let data = keyValues[sender] {
			terminalInputDelegate!.receiveKeyboardInput(data: data)
		}
	}

	@objc private func arrowKeyPressed(_ sender: KeyboardButton) {
		let keyValues: [KeyboardButton: Data] = [
			upKey:    upKeyData,
			downKey:  downKeyData,
			leftKey:  leftKeyData,
			rightKey: rightKeyData
		]
		let keyAppValues: [KeyboardButton: Data] = [
			upKey:    upKeyAppData,
			downKey:  downKeyAppData,
			leftKey:  leftKeyAppData,
			rightKey: rightKeyAppData
		]
		let values = terminalInputDelegate!.applicationCursor ? keyAppValues : keyValues
		if let data = values[sender] {
			terminalInputDelegate!.receiveKeyboardInput(data: data)
		}
	}

	@objc private func arrowRepeatTimerFired(_ timer: Timer) {
		arrowKeyPressed(timer.userInfo as! KeyboardButton)
	}

	@objc func moreKeyPressed() {
		setMoreRowVisible(moreToolbar.isHidden, animated: true)
	}
	
	@objc func arrowKeyLongPressed(_ sender: UILongPressGestureRecognizer) {
		switch sender.state {
		case .began:
			longPressTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.arrowRepeatTimerFired), userInfo: sender.view, repeats: true)
			break

		case .ended, .cancelled:
			longPressTimer?.invalidate()
			longPressTimer = nil
			break

		default:
			break
		}
	}

	@objc func upKeyPressed() {
		arrowKeyPressed(upKey)
	}

	@objc func downKeyPressed() {
		arrowKeyPressed(downKey)
	}

	@objc func leftKeyPressed() {
		arrowKeyPressed(leftKey)
	}

	@objc func rightKeyPressed() {
		arrowKeyPressed(rightKey)
	}

	@objc func metaKeyPressed() {
		inputKeyPressed(metaKey)
	}

	// MARK: - More row

	func setMoreRowVisible(_ visible: Bool, animated: Bool = true) {
		// if we’re already in the specified state, return
		if visible == !moreToolbar.isHidden {
			return
		}

		moreKey.isSelected = visible

		// only hiding is animated
		if !visible && animated {
			UIView.animate(withDuration: 0.2, animations: {
				self.moreToolbar.alpha = 0
			}, completion: { _ in
				self.moreToolbar.isHidden = true
			})
		} else {
			moreToolbar.alpha = visible ? 1 : 0
			moreToolbar.isHidden = !visible
			moreToolbarBottomConstraint.constant = -(textView?.safeAreaInsets.bottom ?? 0)
		}
	}

	// MARK: - Password manager

	func activatePasswordManager() {
		// Trigger the iOS password manager button, or cancel the operation.
		if let passwordInputView = passwordInputView {
			// We’ll become first responder automatically after removing the view.
			passwordInputView.removeFromSuperview()
		} else {
			passwordInputView = TerminalPasswordInputView()
			passwordInputView!.passwordDelegate = self
			addSubview(passwordInputView!)
			passwordInputView!.becomeFirstResponder()
		}
	}

	// MARK: - UITextInput

//	override var textInputView: UIView {
//		// If we have the instance of the text view, return it here so stuff like selection hopefully
//		// works. If not, just return self for the moment.
//		return textView ?? self
//	}

	override var hasText: Bool { true }

	override func insertText(_ text: String) {
		let input = text.data(using: .utf8)!
		var data = Data()

		for character in input {
			var newCharacter = character

			if ctrlDown {
				// Translate capital to lowercase
				if character >= 0x41 && character <= 0x5A { // >= 'A' <= 'Z'
					newCharacter += 0x61 - 0x41 // 'a' - 'A'
				}

				// Convert to the matching control character
				if character >= 0x61 && character <= 0x7A { // >= 'a' <= 'z'
					newCharacter -= 0x61 - 1 // 'a' - 1
				}
			}

			// Convert newline to carriage return
			if character == 0x0A {
				newCharacter = 0x0D
			}

			data.append(contentsOf: [ newCharacter ])
		}

		terminalInputDelegate!.receiveKeyboardInput(data: data)

		if ctrlDown {
			ctrlDown = false
			ctrlKey.isSelected = false
		}

		if !moreToolbar.isHidden {
			setMoreRowVisible(false, animated: true)
		}
	}

	override func deleteBackward() {
		terminalInputDelegate!.receiveKeyboardInput(data: backspaceData)
	}

	func beginFloatingCursor(at point: CGPoint) {
		previousFloatingCursorPoint = point
	}

	func updateFloatingCursor(at point: CGPoint) {
		guard let oldPoint = previousFloatingCursorPoint else {
			return
		}

		let threshold: CGFloat
		switch Preferences.shared.keyboardTrackpadSensitivity {
		case .off:    return
		case .low:    threshold = 8
		case .medium: threshold = 5
		case .high:   threshold = 2
		}

		let difference = point.x - oldPoint.x
		if abs(difference) < threshold {
			return
		}
		if difference < 0 {
			leftKeyPressed()
		} else {
			rightKeyPressed()
		}
		previousFloatingCursorPoint = point
	}

	func endFloatingCursor() {
		previousFloatingCursorPoint = nil
	}

	// MARK: - UIResponder

	override func becomeFirstResponder() -> Bool {
		if let passwordInputView = passwordInputView {
			return passwordInputView.becomeFirstResponder()
		} else {
			_ = super.becomeFirstResponder()
			return true
		}
	}

	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		switch action {
		case #selector(self.paste(_:)):
			// Only paste if the pasteboard contains a plaintext type
			return UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs

		case #selector(self.cut(_:)):
			// Ensure cut is never allowed
			return false

		default:
			return super.canPerformAction(action, withSender: sender)
		}
	}

	override func copy(_ sender: Any?) {
		textView?.copy(sender)
	}

	override func paste(_ sender: Any?) {
		if let data = UIPasteboard.general.string?.data(using: .utf8) {
			terminalInputDelegate!.receiveKeyboardInput(data: data)
		}
	}

}

extension TerminalKeyInput: TerminalPasswordInputViewDelegate {

	func passwordInputViewDidComplete(password: String?) {
		if let password = password {
			// User could have typed on the keyboard while it was in password mode, rather than using the
			// password autofill. Send a return if it seems like a password was actually received,
			// otherwise just pretend it was typed like normal.
			if password.count > 2,
				 let data = password.data(using: .utf8) {
				terminalInputDelegate!.receiveKeyboardInput(data: data)
				terminalInputDelegate!.receiveKeyboardInput(data: returnKeyData)
			} else {
				insertText(password)
			}
		}
		passwordInputView?.removeFromSuperview()
		passwordInputView = nil
		_ = becomeFirstResponder()
	}

}
