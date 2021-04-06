//
//  ViewController.swift
//  CombineIntroMVVMExample
//
//  Created by Eldar Eliav on 06/04/2021.
//

import UIKit
import Combine

/*
 NOTES:
 - Subjects act both as a Subcriber and a Publisher.

 Lecture Order:
 1. VC: button press -> VM actionSubject
 2. what is actionSubject & how VM listens to it
 3. VM: text subjects -> update VC labels
 4. VM: how text subjects are defined (3 types)
 5. VC: how labels are updated via text subjects
    - sink vs assign
    - receiveCompletion
    - declerative
    - cancellables
 6. misc in comments
 */

final class MainViewController: UIViewController {
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!

    private let viewModel = MainViewModel()
    private var cancellables = Set<AnyCancellable>()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // PassthoughSubject
        viewModel.text1SubjectUpdater.sink{ [unowned self] value in
            // receiveValue
            self.label1.text = value
        }.store(in: &cancellables)

        // CurrentValueSubject with Error
        viewModel.text2SubjectUpdater.sink(
            receiveCompletion: { [unowned self] completion in
                // when the publisher was completed - can be called only once
                // failure is also considered a one time completion
                switch completion {
                case .failure(let error):
                    self.label2.text = String(describing: error)
                    self.label2.textColor = .red
                    print(error)
                case .finished:
                    print("success")
                }
            }, receiveValue: { [unowned self] value in
                self.label2.text = value
            }
        ).store(in: &cancellables)

        // CurrentValueSubject
        viewModel.text3SubjectUpdater
            // declerative... oh my
            .receive(on: DispatchQueue.main)
            .map(String.init)
            // we can also use .sink here
            .assign(to: \.text, on: label3)
            .store(in: &cancellables)

        // @Published property wrapper's projected value
        viewModel.$text4SubjectUpdater.sink { [unowned self] value in
            self.label4.text = value
        }.store(in: &cancellables)


// retain cycle - no proper way to avoid it at this point
// BAD: self -> cancellables -> self
// OK: self -> cancellables -> label (and label doesn't point to cancellables or self)
//    .assign(to: \.label.text, on: self)

// decode - basic:
//            .map(\.data)
//            .decode(
//                type: MyModel.self,
//                decoder: JSONDecoder()
//            )

// built-in publishers:
//        let url = URL(string: "https://hello.com")!
//        URLSession.shared.dataTaskPublisher(for: url)
//          .sink(receiveCompletion: { completion in
//            print("data task publisher completed: \(completion)")
//          }, receiveValue: { value in
//            print("received value: \(value)")
//          })

// simple publishers:
//      var mypublisher = [111, 222, 333].publisher   // will send to sink all values, and then .finish
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancellables.forEach { $0.cancel() }
    }

    @IBAction func buttonPressed(_ sender: Any) {
        viewModel.actionSubject.send(.buttonPressed)
    }
}







final class MainViewModel {
    enum Action {
        case buttonPressed
    }

    enum MyError: Error {
        case stopPressingTheButton
    }

    private var cancellables = Set<AnyCancellable>()
    private var count = 0

    // subscribe for updates to following:
    private(set) var text1SubjectUpdater = PassthroughSubject<String, Never>()
    private(set) var text2SubjectUpdater = CurrentValueSubject<String, MyError>("---")
    private(set) var text3SubjectUpdater = CurrentValueSubject<String, Never>("---")

    @Published
    private(set) var text4SubjectUpdater: String = "---"

    // send updates to following:
    var actionSubject = PassthroughSubject<Action, Never>()

    init() {
        let actionCancellable = actionSubject.sink { [unowned self] action in
            switch action {
            case .buttonPressed:
                self.updateTexts()
            }
        }
        cancellables.insert(actionCancellable)
    }

    private func updateTexts() {
        count += 1
        guard count < 10 else {
            finish()
            return
        }

        // PassthoughSubject
        text1SubjectUpdater.send("I am Text A (updated \(count))")

        // CurrentValueSubject with Error
        text2SubjectUpdater.value = "I am Text B (updated \(count))"

        // CurrentValueSubject
        text3SubjectUpdater.send("I am Text C (updated \(count))")

        // @Published
        text4SubjectUpdater = "I am Text D (updated \(count))"
    }

    private func finish() {

        // PassthoughSubject
        text1SubjectUpdater.send("OK!!!")

        // CurrentValueSubject with Error
        text2SubjectUpdater.send(completion: .failure(MyError.stopPressingTheButton))
//        text2SubjectUpdater.send(completion: .finished)

        // CurrentValueSubject
        text3SubjectUpdater.send("that's")

        // @Published
        text4SubjectUpdater = "enough"
    }
}
