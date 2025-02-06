//
//  PDFKitView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
    }
}
