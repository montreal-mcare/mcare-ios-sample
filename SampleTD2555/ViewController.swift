//
//  ViewController.swift
//  SampleTD2555
//
//  Created by Vinicius Consulmagnos Romeiro on 21/12/17.
//  Copyright © 2017 Vinicius Consulmagnos Romeiro. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    @IBOutlet weak var lblInfo: UILabel!
    
    var manager:CBCentralManager!
    var peripheralInternal:CBPeripheral!
    var characteristicInternal:CBCharacteristic!
    var weigthPreviousBytes: Data = Data()
    
    let CHARACTERISTIC_UUID = CBUUID(string: "00001524-1212-EFDE-1523-785FEABCD123")
    let SERVICE_UUID = CBUUID(string: "00001523-1212-EFDE-1523-785FEABCD123")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth not available.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = (advertisementData as NSDictionary)
            .object(forKey: CBAdvertisementDataLocalNameKey)
            as? NSString
        
        if device?.contains("TAIDOC TD2555") == true {
            self.manager.stopScan()
            
            self.peripheralInternal = peripheral
            self.peripheralInternal.delegate = self
            
            manager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            
            if service.uuid == SERVICE_UUID {
                peripheral.discoverCharacteristics(
                    nil,
                    for: thisService
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            
            if thisCharacteristic.uuid == CHARACTERISTIC_UUID {
                self.characteristicInternal = thisCharacteristic
                self.peripheralInternal.setNotifyValue(
                    true,
                    for: thisCharacteristic
                )
                start()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == CHARACTERISTIC_UUID {
            let data = characteristic.value!
            
            if data[1] == 0x52 {
                turnOffDevice()
                return
            }
            
            if data[1] == 0x50 {
                return
            }
            
            print(data.count)
            
            if data.count < 7 {
                return
            }
            
            data.forEach { item in
                weigthPreviousBytes.append(item)
            }
            
            print(weigthPreviousBytes.count)
            
            if weigthPreviousBytes.count > 31 {
                let weight = translateResult(weigthPreviousBytes)
                
                if weight != Double.nan {
                    lblInfo.text = "Medição " + String(weight) + " kg"
                }
                
                clearDevice()
                weigthPreviousBytes = Data()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    private func start() {
        sendCommand([0x51, 0x71, 0x2, 0x0, 0x0, 0xA3])
    }
    
    private func clearDevice() {
        sendCommand([0x51, 0x50, 0x0, 0x0, 0x0, 0x0, 0xA3])
    }
    
    private func turnOffDevice() {
        sendCommand([0x51, 0x52, 0x0, 0x0, 0x0, 0x0, 0xA3])
    }
    
    private func translateResult(_ data: Data?) -> Double {
        guard let data = data else { return Double.nan }
        let byteArray = [UInt8](data)
        guard byteArray.count == 32 else { return Double.nan }
        
        let weight = Double((Int(byteArray[16]) << 8) + Int(byteArray[17])) * 0.1
        if weight > 0 {
            return weight
        }
        
        return Double.nan
    }
    
    private func sendCommand(_ array: [UInt8]) {
        let commandWithChecksum: [UInt8] = applyChecksum(to: array)
        return self.peripheralInternal.writeValue(Data(commandWithChecksum), for: self.characteristicInternal, type: .withResponse)
    }
    
    private func applyChecksum(to array: [UInt8]) -> [UInt8] {
        var newArray = array
        
        let checksum: UInt = array.reduce(0) { (acc, byte) -> UInt in
            return acc + UInt(byte)
        }
        
        let cksum: UInt8 = UInt8(checksum & 0xFF)
        newArray.append(cksum)
        
        return newArray
    }
}

