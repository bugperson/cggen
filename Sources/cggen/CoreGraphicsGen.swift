// Copyright (c) 2017 Yandex LLC. All rights reserved.
// Author: Alfred Zien <zienag@yandex-team.ru>

import Foundation

protocol CoreGraphicsGenerator {
  func filePreamble() -> String
  func funcStart(imageName: String, imageSize: CGSize) -> [String]
  func command(step: DrawStep) -> [String]
  func funcEnd(imageName: String, imageSize: CGSize) -> [String]
}

extension CoreGraphicsGenerator {
  private func generateImageFunction(imgName: String, route: DrawRoute) -> [String] {
    let size = route.boundingRect.size
    let preambleLines = funcStart(imageName: imgName, imageSize: size)
    let commandsLines = route.getSteps().flatMap { command(step: $0) }
    let conclusionLines = funcEnd(imageName: imgName, imageSize: size)
    return preambleLines + commandsLines + conclusionLines
  }
  private func generateImageFunction(nameAndRoute: (String, DrawRoute)) -> String {
    return generateImageFunction(imgName: nameAndRoute.0, route: nameAndRoute.1).joined(separator: "\n")
  }
  func generateFile(namesAndRoutes: [(String, DrawRoute)]) -> String {
    return filePreamble()
      + namesAndRoutes.map({ generateImageFunction(nameAndRoute: $0)}).joined(separator: "\n\n")
      + "\n"
  }
}

struct ObjcCGGenerator: CoreGraphicsGenerator {
  let prefix: String
  let headerImportPath: String?
  private let rgbColorSpaceVarName = "rgbColorSpace"
  private func cmd(_ name: String, _ args: String? = nil) -> String {
    let argStr: String
    if let args = args {
      argStr = ", \(args)"
    } else {
      argStr = ""
    }
    return "  CGContext\(name)(context\(argStr));"
  }
  private func cmd(_ name: String, points: [CGPoint]) -> String {
    return cmd(name, points.map {"(CGFloat)\($0.x), (CGFloat)\($0.y)"}.joined(separator: ", ") )
  }
  private func cmd(_ name: String, rect: CGRect) -> String {
    return cmd(name, "CGRectMake((CGFloat)\(rect.x), (CGFloat)\(rect.y), (CGFloat)\(rect.width), (CGFloat)\(rect.height))" )
  }
  private func cmd(_ name: String, float: CGFloat) -> String {
    return cmd(name, "(CGFloat)\(float)")
  }
  private static var uniqColorID = 0
  private static func asquireUniqColorID() -> Int {
    let uid = uniqColorID
    uniqColorID += 1
    return uid
  }
  private func cmd(_ name: String, color: RGBColor) -> [String] {
    let colorVarName = "color\(ObjcCGGenerator.asquireUniqColorID())"
    let createColor = "  CGColorRef \(colorVarName) = CGColorCreate(\(rgbColorSpaceVarName), (CGFloat []){(CGFloat)\(color.red), (CGFloat)\(color.green), (CGFloat)\(color.blue), 1});"
    let cmdStr = cmd(name, "\(colorVarName)")
    let release = "  CGColorRelease(\(colorVarName));"
    return [createColor, cmdStr, release];
  }
  

  func filePreamble() -> String {
    let importLine: String
    if let headerImportPath = headerImportPath {
      importLine = "#import \"\(headerImportPath)\""
    } else {
      importLine = "#import <CoreGraphics/CoreGraphics.h>"
    }
    return [ "// Generated by cggen", "", importLine, "\n" ].joined(separator: "\n")
  }

  func command(step: DrawStep) -> [String] {
    switch step {
    case .saveGState:
      return [cmd("SaveGState")]
    case .restoreGState:
      return [cmd("RestoreGState")]
    case .moveTo(let p):
      return [cmd("MoveToPoint", points: [p])]
    case .curve(let c1, let c2, let end):
      return [cmd("AddCurveToPoint", points: [c1, c2, end])]
    case .line(let p):
      return [cmd("AddLineToPoint", points: [p])]
    case .closePath:
      return [cmd("ClosePath")]
    case .clip(let rule):
      switch rule {
      case .winding:
        return [cmd("Clip")]
      case .evenOdd:
        return [cmd("EOClip")]
      }
    case .endPath:
      return []
    case .flatness(let flatness):
      return [cmd("SetFlatness", float: flatness)]
    case .nonStrokeColorSpace:
      return []
    case .nonStrokeColor(let color):
      return cmd("SetFillColorWithColor", color: color)
    case .appendRectangle(let rect):
      return [cmd("AddRect", rect: rect)]
    case .fill(let rule):
      switch rule {
      case .winding:
        return [cmd("FillPath")]
      case .evenOdd:
        return [cmd("EOFillPath")]
      }
    case .strokeColorSpace:
      return []
    case .strokeColor(let color):
      return cmd("SetStrokeColorWithColor", color: color)
    case .concatCTM(let transform):
      return [cmd("ConcatCTM", "CGAffineTransformMake(\(transform.a), \(transform.b), \(transform.c), \(transform.d), \(transform.tx), \(transform.ty))")]
    case .lineWidth(let w):
      return [cmd("SetLineWidth", float: w)]
    case .stroke:
      return [cmd("StrokePath")]
    }
  }

  func funcStart(imageName: String, imageSize: CGSize) -> [String] {
    return [
      "void \(prefix)Draw\(imageName)ImageInContext(CGContextRef context) {",
      "  CGColorSpaceRef \(rgbColorSpaceVarName) = CGColorSpaceCreateDeviceRGB();" ]
  }
  func funcEnd(imageName: String, imageSize: CGSize) -> [String] {
    return [ "  CGColorSpaceRelease(\(rgbColorSpaceVarName));", "}" ]
  }
}

struct ObjcHeaderCGGenerator: CoreGraphicsGenerator {
  let prefix: String
  func filePreamble() -> String {
    return [ "// Generated by cggen",
             "",
             "#import <CoreGraphics/CoreGraphics.h>",
             "\n" ].joined(separator: "\n")
  }
  func command(step: DrawStep) -> [String] {
    return []
  }
  func funcStart(imageName: String, imageSize: CGSize) -> [String] {
    return [
      "static const CGSize k\(imageName)ImageSize = (CGSize){.width = \(imageSize.width), .height = \(imageSize.height)};",
      "void \(prefix)Draw\(imageName)ImageInContext(CGContextRef context);",
    ]
  }
  func funcEnd(imageName: String, imageSize: CGSize) -> [String] {
    return []
  }
}
