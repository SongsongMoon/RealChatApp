//
//  ChatLogController.swift
//  RealChatApplication
//
//  Created by 규송 문 on 2017. 6. 8..
//  Copyright © 2017년 규송 문. All rights reserved.
//

import UIKit
import Firebase

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        collectionView?.keyboardDismissMode = .interactive
        
        setupKeyboardObservers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        //Solution to avoid Memory leak
        NotificationCenter.default.removeObserver(self)
    }

    let cellId = "cellId"
    
    var messages = [Message]()
    
    var containerBottomAnchor: NSLayoutConstraint?
    
    var user: User? {
        didSet {
            navigationItem.title = user?.name
            
            observeMessages()
        }
    }
    
    lazy var inputContainerView: ChatInputContainerView = {
        let chatInputcontainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        chatInputcontainerView.chatLogController = self
        return chatInputcontainerView
    }()
    
    func handleUploadTap() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.allowsEditing = true
        imagePickerController.delegate = self
        
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage {
            selectedImageFromPicker = editedImage
        } else if let originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        
        if let selectedImage = selectedImageFromPicker {
            uploadToFirebaseStorageUsingImage(selectedImage)
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func uploadToFirebaseStorageUsingImage(_ selectedImage: UIImage) {
        let imageName = NSUUID().uuidString
        let ref = FIRStorage.storage().reference().child("message_images").child(imageName)
        
        if let uploadImage = UIImageJPEGRepresentation(selectedImage, 0.2) {
            ref.put(uploadImage, metadata: nil, completion: { (metadata, error) in
                if error != nil {
                    print("failed to Upload Image: ", error!)
                    return
                }
                
                if let imageUrl = metadata?.downloadURL()?.absoluteString {
                    self.sendMessageWithImageUrl(imageUrl: imageUrl, image: selectedImage)
                }
            })
        }
    }
    
    private func sendMessageWithImageUrl(imageUrl: String, image: UIImage) {
        
        let properties = ["imageUrl": imageUrl, "imageWidth": image.size.width, "imageHeight": image.size.height] as [String : AnyObject]
        sendMessageWithProperties(properties: properties)
    }
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    func setupKeyboardObservers() {
//        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: .UIKeyboardWillShow, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: .UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: .UIKeyboardDidShow, object: nil)
    }
    
    func handleKeyboardDidShow() {
        if messages.count > 0 {
            let indexPath = NSIndexPath(item: messages.count - 1, section: 0) as IndexPath
            collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }
    
    func  handleKeyboardWillShow(notification: NSNotification) {
        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        
        containerBottomAnchor?.constant = -keyboardFrame!.height
        UIView.animate(withDuration: keyboardDuration!) { 
            self.view.layoutIfNeeded()
        }
    }
    
    func  handleKeyboardWillHide(notification: NSNotification) {
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        
        containerBottomAnchor?.constant = 0
        UIView.animate(withDuration: keyboardDuration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    func observeMessages() {
        
        guard let uid = FIRAuth.auth()?.currentUser?.uid, let toId = user?.id else {
            return
        }
        let userMessagesRef = FIRDatabase.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            let messageId = snapshot.key
            let messageRef = FIRDatabase.database().reference().child("Messages").child(messageId)
            messageRef.observeSingleEvent(of: .value, with: { (snapshot) in
                guard let dictionary = snapshot.value as? [String: AnyObject] else{
                    return
                }
                
                let message = Message(dictionary)
                
                self.messages.append(message)
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                    //scroll to the last index
                    let indexPath = NSIndexPath(item: self.messages.count - 1, section: 0) as IndexPath
                    self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: true)
                }
                
            }, withCancel: nil)
            
        }, withCancel: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatLogController = self
        
        let message = messages[indexPath.item]
        cell.textView.text = message.text
        
        setupCell(cell, message: message)
        
        //bubbleView Width
        if let text = message.text {
            //if message is text message, fall in here
            cell.bubbleViewWidthAnchor?.constant = estimateFrameForText(text).width + 32
            cell.textView.isHidden = false
            
        } else if message.imageUrl != nil {
            //if message is image message, fall in here
            cell.bubbleViewWidthAnchor?.constant = 200
            cell.textView.isHidden = true
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        //bubbleView Height
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        if let text = message.text {
            //if message is text message, fall in here <Height>
            height = estimateFrameForText(text).height + 20
        } else if let imageWidth = message.imageWidth?.floatValue, let imageHeight = message.imageHeight?.floatValue {
            //if message is image message, fall in here <Height>
            //original image ratio = image message ratio
            //fix the image message width (cell.bubbleViewWidthAnchor?.constant = 200)
            //h1 / w1 = h2 / w2
            //solve for h1
            //h1 = h2 / w2 * w1
            height = CGFloat(imageHeight / imageWidth * 200)
        }
        
        let width = UIScreen.main.bounds.width
        return CGSize(width: width, height: height)
    }
    
    private func setupCell(_ cell: ChatMessageCell, message: Message) {
        if let profileImageUrl = self.user?.profileImageUrl {
            cell.profileImageView.loadImageUsingCacheWithUrlString(urlString: profileImageUrl)
        }
        
        if message.fromId == FIRAuth.auth()?.currentUser?.uid {
            //Outgoing Message is Blue bubbleView
            cell.bubbleView.backgroundColor = UIColor(r: 0, g: 137, b: 249)
            cell.textView.textColor = UIColor.white
            
            cell.profileImageView.isHidden = true
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        } else {
            //Incoming Message is Gray bubbleView
            cell.bubbleView.backgroundColor = UIColor(r: 240, g: 240, b: 240)
            cell.textView.textColor = UIColor.black
            
            cell.profileImageView.isHidden = false
            
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.loadImageUsingCacheWithUrlString(urlString: messageImageUrl)
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = UIColor.clear
        } else {
            cell.messageImageView.isHidden = true
        }
    }
    
    private func estimateFrameForText(_ text: String) -> CGRect {
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    func handleSend() {
        let properties = ["text": inputContainerView.inputTextField.text!] as [String: AnyObject]
        sendMessageWithProperties(properties: properties)
    }
    
    private func sendMessageWithProperties(properties: [String: AnyObject]){
        let ref = FIRDatabase.database().reference().child("Messages")
        let childRef = ref.childByAutoId()
        let toId = user!.id!
        let fromId = FIRAuth.auth()!.currentUser!.uid
        let timestamp = NSNumber(value: Int(Date().timeIntervalSince1970))
        var values = ["toId": toId, "fromId": fromId, "timestamp": timestamp] as [String : AnyObject]
        
        //append properties dictionary onto values some how?
        //key $0, value $1
        properties.forEach({values[$0] = $1})
        
        
        childRef.updateChildValues(values) {
            (error,ref) in
            if error != nil {
                print(error!)
                return
            }
            
            self.inputContainerView.inputTextField.text = nil
            
            let userMessagesRef = FIRDatabase.database().reference().child("user-messages").child(fromId).child(toId)
            let messageId = childRef.key
            userMessagesRef.updateChildValues([messageId: 1])
            
            let recipientUserMessagesRef = FIRDatabase.database().reference().child("user-messages").child(toId).child(fromId)
            recipientUserMessagesRef.updateChildValues([messageId: 1])
        }
    }
    
    var startingFrame: CGRect?
    var blackBackgroundView: UIView?
    var startingImageView: UIImageView?
    
    //my custom zooming logic
    func performZoomInForImageView(_ startingImageView: UIImageView) {
        self.startingImageView = startingImageView
        self.startingImageView?.isHidden = true
        //performing zoom in logic in controller
        startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        let zoomingImageView = UIImageView(frame: startingFrame!)
        zoomingImageView.backgroundColor = UIColor.red
        zoomingImageView.image = startingImageView.image
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleZoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow {
            
            blackBackgroundView = UIView(frame: keyWindow.frame)
            blackBackgroundView?.backgroundColor = UIColor.black
            blackBackgroundView?.alpha = 0
            keyWindow.addSubview(blackBackgroundView!)
            keyWindow.addSubview(zoomingImageView)
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.blackBackgroundView?.alpha = 1
                self.inputContainerView.alpha = 0
                // h2/w1 = h1/w1
                // h2 = h1/w1 * w1
                let height = (self.startingFrame?.height)! / (self.startingFrame?.width)! * keyWindow.frame.width
                
                zoomingImageView.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                zoomingImageView.center = keyWindow.center
                
            }, completion: { (completed) in
                //zoomOutImageView.removeFromSuperview()
            })
            
        }
    }
    
    func handleZoomOut(tapGesture: UITapGestureRecognizer) {
        if let zoomOutImageView = tapGesture.view {
            //animate back out to controller
            zoomOutImageView.layer.cornerRadius = 16
            zoomOutImageView.clipsToBounds = true
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: { 
                zoomOutImageView.frame = self.startingFrame!
                self.blackBackgroundView?.alpha = 0
                self.inputContainerView.alpha = 1
                
            }, completion: { (completed) in
                zoomOutImageView.removeFromSuperview()
                self.startingImageView?.isHidden = false
            })
        }
    }
    
}


























