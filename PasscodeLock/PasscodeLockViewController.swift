//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit

open class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate {
    
    public enum LockState {
        case enterPasscode
        case setPasscode
        case changePasscode
        case removePasscode
        
		func getState(_ stringsToShow: StringsToBeDisplayed?) -> PasscodeLockStateType {
            
            switch self {
			case .enterPasscode: 	return EnterPasscodeState(stringsToShow: stringsToShow)
			case .setPasscode: 		return SetPasscodeState(stringsToShow: stringsToShow)
			case .changePasscode: 	return ChangePasscodeState(stringsToShow: stringsToShow)
            case .removePasscode: 	return EnterPasscodeState(allowCancellation: true, stringsToShow: stringsToShow)
            }
        }
    }
    
    @IBOutlet open weak var titleLabel				: UILabel?
	@IBOutlet open weak var customImageView			: UIImageView?
    @IBOutlet open weak var descriptionLabel			: UILabel?
    @IBOutlet open var placeholders					: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
	@IBOutlet open weak var cancelDeleteButton		: UIButton?
    @IBOutlet open weak var touchIDButton				: UIButton?
    @IBOutlet open weak var placeholdersX				: NSLayoutConstraint?
    
    open var successCallback							: ((_ lock: PasscodeLockType) -> Void)?
	open var customImage 								: UIImage?
    open var dismissCompletionCallback				: (()->Void)?
    open var animateOnDismiss							: Bool
    open var notificationCenter						: NotificationCenter?
	open var stringsToShow							: StringsToBeDisplayed?
	open var closingView								: Bool = false
    
    internal let passcodeConfiguration					: PasscodeLockConfigurationType
    internal let passcodeLock							: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted 		= true
    
    fileprivate var shouldTryToAuthenticateWithBiometrics 	= true
    
    // MARK: - Initializers
    
	public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true, stringToShow: StringsToBeDisplayed?) {

		self.stringsToShow = stringToShow
        self.animateOnDismiss = animateOnDismiss
        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        let nibName = "PasscodeLockView"
        let bundle: Bundle = bundleForResource(nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundle)
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
    }
    
	public convenience init(state: LockState, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true, stringsToShow: StringsToBeDisplayed?) {
        
        self.init(state: state.getState(stringsToShow), configuration: configuration, animateOnDismiss: animateOnDismiss, stringToShow: stringsToShow)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        clearEvents()
    }
    
    // MARK: - View
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        updatePasscodeView()
        setupEvents()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldTryToAuthenticateWithBiometrics {
            authenticateWithBiometrics()
        }
    }
    
    internal func updatePasscodeView() {

		customImageView?.image = self.customImage
        titleLabel?.text = passcodeLock.state.title
        descriptionLabel?.text = passcodeLock.state.description
        touchIDButton?.isHidden = !passcodeLock.isTouchIDAllowed
		touchIDButton?.setTitle((self.stringsToShow?.useTouchID ?? localizedStringFor("UseTouchId", comment: "")), for: UIControlState())
		self.cancelDeleteButtonSetup()
    }
    
    // MARK: - Events
    
    fileprivate func setupEvents() {
        
        notificationCenter?.addObserver(self, selector: #selector(self.appWillEnterForegroundHandler(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.addObserver(self, selector: #selector(PasscodeLockViewController.appDidEnterBackgroundHandler(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    fileprivate func clearEvents() {
        
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    open func appWillEnterForegroundHandler(_ notification: Notification) {
        
        authenticateWithBiometrics()
    }
    
    open func appDidEnterBackgroundHandler(_ notification: Notification) {
        
        shouldTryToAuthenticateWithBiometrics = false
    }
    
    // MARK: - Actions
    
    @IBAction func passcodeSignButtonTap(_ sender: PasscodeSignButton) {
        
        guard isPlaceholdersAnimationCompleted else {
			return
		}
        
        passcodeLock.addSign(sender.passcodeSign)
    }
    
    @IBAction func cancelButtonTap(_ sender: UIButton) {
        
        dismissPasscodeLock(passcodeLock)
    }
    
    @IBAction func deleteSignButtonTap(_ sender: UIButton) {

		if (passcodeLock.isPincodeEmpty == true && passcodeLock.state.isCancellableAction == true) {
			dismissPasscodeLock(passcodeLock)

		} else {
			passcodeLock.removeSign()
		}
    }
    
    @IBAction func touchIDButtonTap(_ sender: UIButton) {
        
        passcodeLock.authenticateWithBiometrics(self.stringsToShow)
    }
    
    fileprivate func authenticateWithBiometrics() {
        
        if (passcodeConfiguration.shouldRequestTouchIDImmediately == true && passcodeLock.isTouchIDAllowed == true) {
            passcodeLock.authenticateWithBiometrics(self.stringsToShow)
        }
    }
    
    internal func dismissPasscodeLock(_ lock: PasscodeLockType, completionHandler: (() -> Void)? = nil) {
        
        // if presented as modal
        if (presentingViewController?.presentedViewController == self) {
            
            dismiss(animated: animateOnDismiss, completion: { [weak self] _ in
                self?.dismissCompletionCallback?()
                completionHandler?()
            })
            
            return
            
        // if pushed in a navigation controller
        } else if navigationController != nil {
            navigationController?.popViewController(animated: animateOnDismiss)
        }
        
        dismissCompletionCallback?()
        completionHandler?()
    }
    
    // MARK: - Animations
    
    internal func animateWrongPassword() {

		self.cancelDeleteButtonSetup()
        isPlaceholdersAnimationCompleted = false
        
        animatePlaceholders(placeholders, toState: .error)
        
        placeholdersX?.constant = -40
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.2, initialSpringVelocity: 0, options: [], animations: {
                self.placeholdersX?.constant = 0
                self.view.layoutIfNeeded()

		}, completion: { completed in
                self.isPlaceholdersAnimationCompleted = true
                self.animatePlaceholders(self.placeholders, toState: .inactive)
        })
    }
    
    internal func animatePlaceholders(_ placeholders: [PasscodeSignPlaceholderView], toState state: PasscodeSignPlaceholderView.State) {
        
        for placeholder in placeholders {
            placeholder.animateState(state)
        }
    }
    
    fileprivate func animatePlacehodlerAtIndex(_ index: Int, toState state: PasscodeSignPlaceholderView.State) {
        
        guard (index < placeholders.count && index >= 0) else {
			return
		}
        
        placeholders[index].animateState(state)
    }

    // MARK: - PasscodeLockDelegate
    
    open func passcodeLockDidSucceed(_ lock: PasscodeLockType) {

		self.cancelDeleteButtonSetup()
        animatePlaceholders(placeholders, toState: .inactive)
        dismissPasscodeLock(lock, completionHandler: { [weak self] _ in
            self?.successCallback?(lock)
        })
    }
    
    open func passcodeLockDidFail(_ lock: PasscodeLockType) {
        
        animateWrongPassword()
    }
    
    open func passcodeLockDidChangeState(_ lock: PasscodeLockType) {
        
        updatePasscodeView()
        animatePlaceholders(placeholders, toState: .inactive)
		self.cancelDeleteButtonSetup()
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, addedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .active)
		self.cancelDeleteButtonSetup()
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, removedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .inactive)
        
        if (index == 0) {
            self.cancelDeleteButtonSetup()
        }
    }

	open func cancelDeleteButtonSetup() {
		
		let cancelButton = ((self.passcodeLock.isPincodeEmpty == true) ? (self.stringsToShow?.cancel ?? localizedStringFor("Cancel", comment: "")) : (self.stringsToShow?.delete ?? localizedStringFor("Delete", comment: "")))
		let titleForButton = ((self.passcodeLock.state.isCancellableAction == true) ? cancelButton : (self.stringsToShow?.delete ?? localizedStringFor("Delete", comment: "")))
		self.cancelDeleteButton?.setTitle(titleForButton, for: UIControlState())

		if (self.passcodeLock.isPincodeEmpty == true && self.passcodeLock.state.isCancellableAction == false) {
			self.cancelDeleteButton?.isEnabled = false
		} else {
			self.cancelDeleteButton?.isEnabled = true
		}
	}
}
