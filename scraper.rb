require 'nokogiri'
require 'pry'
require 'mechanize'
require 'watir'
require 'webdrivers'

def set_variables
  @nome_bairro = 'Barra da Tijuca'
end

def set_webdriver
  Selenium::WebDriver::Chrome::Service.driver_path=File.join(Dir.pwd, 'chromedriver.exe')
  
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_option(:detach, true)
  options.add_argument("start-maximized")
  options.add_preference('webkit.webprefs.loads_images_automatically', false)

  @browser = Watir::Browser.new :chrome, :options => options
end

def scraper
  set_variables
  set_webdriver
  
  url = 'https://www.vivareal.com.br/'
  @browser.goto(url)
  
  form = @browser.form(class: %w(main-search__form js-base-search))
  return false unless form.exist?
  
  form.select_list(class: 'js-select-business').option(value: 'rent').select
  # checar se é possível pegar o select apenas se ele contiver uma palavra do value, como por exemplo
  # se value contém apartment, então seleciona essa opção
  form.select_list(class: 'js-select-type').option(value: 'APARTMENT|UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX|RESIDENTIAL|APARTMENT').select
  form.text_field.set(@nome_bairro)

  bairro_element = form.li(data_type: 'neighborhood')
  if bairro_element.text.split(', ')[0].downcase == @nome_bairro.downcase
    bairro_element.click
  end
end

scraper