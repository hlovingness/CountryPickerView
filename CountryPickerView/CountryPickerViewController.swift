//
//  CountryPickerViewController.swift
//  CountryPickerView
//
//  Created by Kizito Nwose on 18/09/2017.
//  Copyright © 2017 Kizito Nwose. All rights reserved.
//

import UIKit

public class CountryPickerViewController: UITableViewController {

    public var searchController: UISearchController?
    fileprivate var searchResults = [Country]()
    fileprivate var isSearchMode = false
    fileprivate var sectionsTitles = [String]()
    fileprivate var countries = [String: [Country]]()
    fileprivate var hasPreferredSection: Bool {
        return dataSource.preferredCountriesSectionTitle != nil &&
            dataSource.preferredCountries.count > 0
    }
    fileprivate var showOnlyPreferredSection: Bool {
        return dataSource.showOnlyPreferredSection
    }
    internal weak var countryPickerView: CountryPickerView! {
        didSet {
            dataSource = CountryPickerViewDataSourceInternal(view: countryPickerView)
        }
    }
    
    fileprivate var dataSource: CountryPickerViewDataSourceInternal!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        prepareTableItems()
        prepareNavItem()
        prepareSearchBar()
    }
   
}

// UI Setup
extension CountryPickerViewController {
    
    func prepareTableItems()  {
        if !showOnlyPreferredSection {
            let countriesArray = countryPickerView.usableCountries
            let locale = dataSource.localeForCountryNameInList
            
            // 自定义中文拼音分组逻辑
            var groupedData = [String: [Country]]()
            
            // 步骤1: 将国家按中文拼音首字母分组
            for country in countriesArray {
                // 获取中文国家名（需确保locale为中文）
                let chineseName = country.localizedName(locale) ?? country.name
                
                // 转换为拼音并取首字母
                let pinyin = chineseName.transformToPinyin()
                guard let firstLetter = pinyin.first else { continue }
                let groupKey = String(firstLetter).uppercased()
                
                // 添加到分组字典
                if groupedData[groupKey] == nil {
                    groupedData[groupKey] = [Country]()
                }
                groupedData[groupKey]?.append(country)
            }
            
            // 步骤2: 对每个分组内的国家按中文拼音排序
            groupedData.forEach { key, value in
                groupedData[key] = value.sorted { lhs, rhs in
                    let lhsName = lhs.localizedName(locale) ?? lhs.name
                    let rhsName = rhs.localizedName(locale) ?? rhs.name
                    return lhsName.compare(rhsName, locale: locale) == .orderedAscending
                }
            }
            
            countries = groupedData
            sectionsTitles = groupedData.keys.sorted()
        }
        
        // 添加偏好国家分组（原逻辑不变）
        if hasPreferredSection, let preferredTitle = dataSource.preferredCountriesSectionTitle {
            sectionsTitles.insert(preferredTitle, at: sectionsTitles.startIndex)
            countries[preferredTitle] = dataSource.preferredCountries
        }
        
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
    }
    
    func prepareNavItem() {
        navigationItem.title = dataSource.navigationTitle

        // Add a close button if this is the root view controller
        if navigationController?.viewControllers.count == 1 {
            let closeButton = dataSource.closeButtonNavigationItem
            closeButton.target = self
            closeButton.action = #selector(close)
            navigationItem.leftBarButtonItem = closeButton
        }
    }
    
    func prepareSearchBar() {
        let searchBarPosition = dataSource.searchBarPosition
        if searchBarPosition == .hidden  {
            return
        }
        searchController = UISearchController(searchResultsController:  nil)
        searchController?.searchResultsUpdater = self
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = searchBarPosition == .tableViewHeader
        searchController?.definesPresentationContext = true
        searchController?.searchBar.delegate = self
        searchController?.delegate = self

        switch searchBarPosition {
        case .tableViewHeader: tableView.tableHeaderView = searchController?.searchBar
        case .navigationBar: navigationItem.titleView = searchController?.searchBar
        default: break
        }
    }
    
    @objc private func close() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

//MARK:- UITableViewDataSource
extension CountryPickerViewController {
    
    override public func numberOfSections(in tableView: UITableView) -> Int {
        return isSearchMode ? 1 : sectionsTitles.count
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearchMode ? searchResults.count : countries[sectionsTitles[section]]!.count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = String(describing: CountryTableViewCell.self)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CountryTableViewCell
            ?? CountryTableViewCell(style: .default, reuseIdentifier: identifier)
        
        let country = isSearchMode ? searchResults[indexPath.row]
            : countries[sectionsTitles[indexPath.section]]![indexPath.row]

        var name = country.localizedName(dataSource.localeForCountryNameInList) ?? country.name
        if dataSource.showCountryCodeInList {
            name = "\(name) (\(country.code))"
        }
        if dataSource.showPhoneCodeInList {
            name = "\(name) (\u{202A}\(country.phoneCode)\u{202C})"
        }
        cell.imageView?.image = country.flag
        
        cell.flgSize = dataSource.cellImageViewSize
        cell.imageView?.clipsToBounds = true

        cell.imageView?.layer.cornerRadius = dataSource.cellImageViewCornerRadius
        cell.imageView?.layer.masksToBounds = true
        
        cell.textLabel?.text = name
        cell.textLabel?.font = dataSource.cellLabelFont
        if let color = dataSource.cellLabelColor {
            cell.textLabel?.textColor = color
        }
        cell.accessoryType = country == countryPickerView.selectedCountry &&
            dataSource.showCheckmarkInList ? .checkmark : .none
        cell.separatorInset = .zero
        return cell
    }
    
    override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return isSearchMode ? nil : sectionsTitles[section]
    }
    
    override public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isSearchMode {
            return nil
        } else {
            if hasPreferredSection {
                return Array<String>(sectionsTitles.dropFirst())
            }
            return sectionsTitles
        }
    }
    
    override public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return sectionsTitles.firstIndex(of: title)!
    }
}

//MARK:- UITableViewDelegate
extension CountryPickerViewController {

    override public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = dataSource.sectionTitleLabelFont
            if let color = dataSource.sectionTitleLabelColor {
                header.textLabel?.textColor = color
            }
        }
    }
    
    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let country = isSearchMode ? searchResults[indexPath.row]
            : countries[sectionsTitles[indexPath.section]]![indexPath.row]

        searchController?.isActive = false
        searchController?.dismiss(animated: false, completion: nil)
        
        let completion = {
            self.countryPickerView.selectedCountry = country
        }
        // If this is root, dismiss, else pop
        if navigationController?.viewControllers.count == 1 {
            navigationController?.dismiss(animated: true, completion: completion)
        } else {
            navigationController?.popViewController(animated: true, completion: completion)
        }
    }
}

// MARK:- UISearchResultsUpdating
extension CountryPickerViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        isSearchMode = false
        guard let text = searchController.searchBar.text, text.count > 0 else {
            tableView.reloadData()
            return
        }
        isSearchMode = true
        
        let query = text.lowercased()
        var indexArray = [Country]()
        
        // 判断输入是否包含中文字符
        if query.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil {
            // 输入包含中文，则遍历所有国家
            indexArray = countryPickerView.usableCountries
        } else {
            // 输入不包含中文，假设是拼音，则从分组字典中取出对应组
            if let array = countries[String(text.capitalized[text.startIndex])] {
                indexArray = array
            }
        }
        
        // 根据中文和拼音都进行匹配
        searchResults = indexArray.filter { country in
            let localized = (country.localizedName(dataSource.localeForCountryNameInList) ?? country.name)
            let pinyin = localized.transformToPinyin().lowercased()
            return localized.lowercased().hasPrefix(query) || pinyin.hasPrefix(query) ||
                (dataSource.showCountryCodeInList && country.code.lowercased().hasPrefix(query))
        }
        
        tableView.reloadData()
    }
}

// MARK:- UISearchBarDelegate
extension CountryPickerViewController: UISearchBarDelegate {
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Hide the back/left navigationItem button
        navigationItem.leftBarButtonItem = nil
        navigationItem.hidesBackButton = true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Show the back/left navigationItem button
        prepareNavItem()
        navigationItem.hidesBackButton = false
    }
}

// MARK:- UISearchControllerDelegate
// Fixes an issue where the search bar goes off screen sometimes.
extension CountryPickerViewController: UISearchControllerDelegate {
    public func willPresentSearchController(_ searchController: UISearchController) {
    }
    
    public func willDismissSearchController(_ searchController: UISearchController) {
    }
}

// MARK:- CountryTableViewCell.
class CountryTableViewCell: UITableViewCell {
    
    var flgSize: CGSize = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame.size = flgSize
        imageView?.center.y = contentView.center.y
    }
}


// MARK:- An internal implementation of the CountryPickerViewDataSource.
// Returns default options where necessary if the data source is not set.
class CountryPickerViewDataSourceInternal: CountryPickerViewDataSource {
    
    private unowned var view: CountryPickerView
    
    init(view: CountryPickerView) {
        self.view = view
    }
    
    var preferredCountries: [Country] {
        return view.dataSource?.preferredCountries(in: view) ?? preferredCountries(in: view)
    }
    
    var preferredCountriesSectionTitle: String? {
        return view.dataSource?.sectionTitleForPreferredCountries(in: view)
    }
    
    var showOnlyPreferredSection: Bool {
        return view.dataSource?.showOnlyPreferredSection(in: view) ?? showOnlyPreferredSection(in: view)
    }
    
    var sectionTitleLabelFont: UIFont {
        return view.dataSource?.sectionTitleLabelFont(in: view) ?? sectionTitleLabelFont(in: view)
    }

    var sectionTitleLabelColor: UIColor? {
        return view.dataSource?.sectionTitleLabelColor(in: view)
    }
    
    var cellLabelFont: UIFont {
        return view.dataSource?.cellLabelFont(in: view) ?? cellLabelFont(in: view)
    }
    
    var cellLabelColor: UIColor? {
        return view.dataSource?.cellLabelColor(in: view)
    }
    
    var cellImageViewSize: CGSize {
        return view.dataSource?.cellImageViewSize(in: view) ?? cellImageViewSize(in: view)
    }
    
    var cellImageViewCornerRadius: CGFloat {
        return view.dataSource?.cellImageViewCornerRadius(in: view) ?? cellImageViewCornerRadius(in: view)
    }
    
    var navigationTitle: String? {
        return view.dataSource?.navigationTitle(in: view)
    }
    
    var closeButtonNavigationItem: UIBarButtonItem {
        guard let button = view.dataSource?.closeButtonNavigationItem(in: view) else {
            return UIBarButtonItem(title: "Close", style: .done, target: nil, action: nil)
        }
        return button
    }
    
    var searchBarPosition: SearchBarPosition {
        return view.dataSource?.searchBarPosition(in: view) ?? searchBarPosition(in: view)
    }
    
    var showPhoneCodeInList: Bool {
        return view.dataSource?.showPhoneCodeInList(in: view) ?? showPhoneCodeInList(in: view)
    }
    
    var showCountryCodeInList: Bool {
        return view.dataSource?.showCountryCodeInList(in: view) ?? showCountryCodeInList(in: view)
    }
    
    var showCheckmarkInList: Bool {
        return view.dataSource?.showCheckmarkInList(in: view) ?? showCheckmarkInList(in: view)
    }
    
    var localeForCountryNameInList: Locale {
        return view.dataSource?.localeForCountryNameInList(in: view) ?? localeForCountryNameInList(in: view)
    }
    
    var excludedCountries: [Country] {
        return view.dataSource?.excludedCountries(in: view) ?? excludedCountries(in: view)
    }
}

// MARK: - 拼音转换扩展
extension String {
    /// 将中文字符串转换为无空格拼音（大写字母开头）
    func transformToPinyin() -> String {
        let mutableString = NSMutableString(string: self)
        // 转换为带音标的拼音
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        // 去除音标
        CFStringTransform(mutableString, nil, kCFStringTransformStripCombiningMarks, false)
        // 转换为大写无空格字符串（如"ZHONGGUO"）
        return mutableString.capitalized.replacingOccurrences(of: " ", with: "")
    }
}
