module DevicesHelper
  def devices_kinds_for_select
    [ 
      [Device::KIND_CPE, I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_CPE}")],
      [Device::KIND_AP, I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_AP}")],
      [Device::KIND_SWITCH, I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_SWITCH}")],
      [Device::KIND_SERVER, I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_SERVER}")],
      [Device::KIND_ROUTER, I18n.t("activerecord.attributes.device.kinds.#{Device::KIND_ROUTER}")]
    ]
  end
end
