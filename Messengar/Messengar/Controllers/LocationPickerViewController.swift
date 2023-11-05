//
//  LocationPickerViewController.swift
//  Messengar
//
//  Created by 김우섭 on 11/5/23.
//

import UIKit
import CoreLocation
import MapKit

class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private var isPickable = true
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinates = coordinates
        self.isPickable = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // 좌표가 제공되지 않았거나 유효하지 않을 경우 기본 좌표 설정
        if coordinates == nil {
            // 서울의 좌표를 기본값으로 설정
            coordinates = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
            isPickable = true
        }
        
        // 지도의 중심을 초기화된 좌표로 설정
        if let initialCoordinates = coordinates {
            let region = MKCoordinateRegion(center: initialCoordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
            map.setRegion(region, animated: true)
        }
        
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "보내기",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self,
                                                 action: #selector(didTapMap))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            // just 위치보여주기
            if let validCoordinates = coordinates {
                let pin = MKPointAnnotation()
                pin.coordinate = validCoordinates
                map.addAnnotation(pin)
            }
        }
        view.addSubview(map)
    }
    
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        
        // 위치에 핀 꽂기
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
}
