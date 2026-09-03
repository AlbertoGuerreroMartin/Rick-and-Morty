//
//  SectionViewContract.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import SwiftUI

public protocol SectionViewContract: View {
    associatedtype ViewModel
    associatedtype RenderModel

    var viewModel: ViewModel { get }
    var renderModelPublisher: AnyPublisher<RenderModel, Never> { get }
    
    init(viewModel: ViewModel, renderModelPublisher: AnyPublisher<RenderModel, Never>)
}
