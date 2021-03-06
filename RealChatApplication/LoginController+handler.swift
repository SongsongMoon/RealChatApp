//
//  LoginController+handler.swift
//  RealChatApplication
//
//  Created by 규송 문 on 2017. 6. 6..
//  Copyright © 2017년 규송 문. All rights reserved.
//

import UIKit
import Firebase

extension LoginController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func handleSelectProfileImageView () {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        self.dismiss(animated: true, completion: nil)
        
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage {
            selectedImageFromPicker = editedImage
        } else if let originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        
        if let selectedImage = selectedImageFromPicker {
            profileImageView.image = selectedImage
        }
 
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    private func registerUserIntoDatabaseWithUid(uid: String, values: [String: String]) {
        let ref = FIRDatabase.database().reference()
        
        let userReference = ref.child("users").child(uid)
        
        userReference.updateChildValues(values, withCompletionBlock: { (err, ref) in
            if err != nil {
                print (err!)
                return
            }
            
            //self.messagesController?.navigationItem.title = values["name"]
            let user = User()
            user.setValuesForKeys(values)
            self.messagesController?.setupNavBarWithUser(user)
            self.dismiss(animated: true, completion: nil)
        })
    }
    
    func handleRegister() {
        guard let email = emailTextField.text, let password = passwordTextField.text, let name = nameTextField.text else {
            print("Form is not valid")
            return
        }
        
        FIRAuth.auth()?.createUser(withEmail: email, password: password, completion: { (user: FIRUser?, error) in
            if error != nil {
                print(error!)
                return
            }
            
            guard let uid = user?.uid else{
                return
            }
            
            //successfully authenticated user
            //upload profile image
            let imageName = NSUUID().uuidString
            let storageRef = FIRStorage.storage().reference().child("Profile_images").child("\(imageName).png")
            
            //To speed up, using JPEG format instead of PNG format
            //if let uploadData = UIImagePNGRepresentation(self.profileImageView.image!) {
            if let profileImage = self.profileImageView.image, let uploadData = UIImageJPEGRepresentation(profileImage, 0.1) {
                storageRef.put(uploadData, metadata: nil, completion: { (metadata, error) in
                    
                    if error != nil {
                        print(error!)
                        return
                    }
                    
                    if let profileImageUrl = metadata?.downloadURL()?.absoluteString {
                        let values = ["name" : name, "email" : email, "profileImageUrl" : profileImageUrl]
                        self.registerUserIntoDatabaseWithUid(uid: uid, values: values)
                    }
                })
            }
        })
    }
}
