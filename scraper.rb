require 'nokogiri'
require 'pry'
require 'mechanize'
require 'watir'
require 'webdrivers'

def set_variables
  @neighborhood_name = 'Catete'
  @city_name = 'Rio de Janeiro'
  @bedrooms = 2
  @min_price = 0
  @max_price = 2000
end

def set_webdriver
  chrome_driver_path = File.expand_path("../..", Dir.pwd)
  Selenium::WebDriver::Chrome::Service.driver_path=File.join(chrome_driver_path, 'chromedriver.exe')
  
  options = Selenium::WebDriver::Chrome::Options.new
  # options.add_option(:detach, true)
  options.add_argument("start-maximized")
  # options.add_preference('webkit.webprefs.loads_images_automatically', false)

  @browser = Watir::Browser.new :chrome, :options => options
end

def viva_real
  set_variables
  set_webdriver
  
  url = 'https://www.vivareal.com.br/'
  @browser.goto(url)
  
  form = @browser.form(class: %w(main-search__form js-base-search))
  return false unless form.exist?
  
  sleep(2)
  form.select_list(class: 'js-select-business').option(value: 'rent').select
  form.select_list(class: 'js-select-type').option(value: 'APARTMENT|UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX|RESIDENTIAL|APARTMENT').select
  form.text_field.set(@neighborhood_name)
  sleep(5)

  neighborhood_elements = form.lis(data_type: 'neighborhood')
  neighborhood_elements.each do |ne|
    if (ne.text.split(', ')[0].downcase == @neighborhood_name.downcase) && ( ne.text.split(', ')[1].split(' -')[0].downcase == @city_name.downcase)
      ne.click
      break
    end
  end
  sleep(2)
  
  binding.pry
  form2 = @browser.form
  # min_price = form2.div(class: 'filter-range__container').text_field(id: 'filter-range-from-price')
  # min_price.set(@min_price)
  max_price = form2.div(class: 'filter-range__container').text_field(id: 'filter-range-to-price')
  max_price.set(@max_price)
  form2.div(class: %w(form__pills js-bedrooms-quantity)).ul(class: %w(filter-pills js-container)).button(data_value: @bedrooms.to_s).click
  sleep(2)
  
  total_pages = @browser.lis(class: 'pagination__item', data_type: 'number').length
  
  total_data = []
  loop do
    total_data << collect_data
    pagina_atual = @browser.link(class: 'js-change-page', data_active: true).data_page.to_i
    if pagina_atual == total_pages
      break
    end
    proxima_pagina.click
    sleep(2)
    pagina_atual = @browser.link(class: 'js-change-page', data_active: true).data_page.to_i
    proxima_pagina = @browser.link(class: 'js-change-page', data_page: (pagina_atual + 1).to_s)
  end
  
  # binding.pry
end

def collect_data
  page_data = []
  for i in 0..(@browser.divs(data_type: 'property').length-1)
    properties = @browser.divs(data_type: 'property')[i]
    
    info = properties.div(class: 'property-card__main-content').ul(class: 'property-card__details')
    area = info.li(class: 'property-card__detail-area').text
    rooms = info.li(class: 'js-property-detail-rooms').text
    suites = info.li(class: 'js-property-detail-suites').text
    bathrooms = info.li(class: 'js-property-detail-bathroom').text
    garage_spot = info.li(class: 'js-property-detail-garages').text
    
    values = properties.div(class: 'property-card__main-content').section(class: 'property-card__values')
    price = values.div(class: 'js-property-card-prices').text
    if values.div(class: 'property-card__price-details--condo').exist?
      condominio = values.div(class: 'property-card__price-details--condo').text.split('R$ ')[1]
    else
      condominio = ''
    end
    
    page_data[i] = {
      area: area,
      rooms: rooms,
      suites: suites,
      bathrooms: bathrooms,
      garage_spot: garage_spot,
      price: price,
      condominio: condominio
    }
  end
  return page_data
end

viva_real

