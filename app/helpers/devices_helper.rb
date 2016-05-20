module DevicesHelper
  def devices_kinds_for_select
    [
      [I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_CPE}"), Device::KIND_CPE],
      [I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_AP}"), Device::KIND_AP],
      [I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_SWITCH}"), Device::KIND_SWITCH],
      [I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_SERVER}"), Device::KIND_SERVER],
      [I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_ROUTER}"), Device::KIND_ROUTER]
    ]
  end

  def devices_brands_for_select
    [
     ["Ubiquiti", Device::BRAND_UBIQUITI],
     ["MikroTik", Device::BRAND_MIKROTIK],
     ["Cisco", Device::BRAND_CISCO],
     [I18n.t("activerecord.attributes.device.brands.other"), Device::BRAND_OTHER]
    ]
  end
end