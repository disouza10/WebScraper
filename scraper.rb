require 'nokogiri'
require 'httparty'
require 'pry'
require 'mechanize'
require 'watir'
require 'webdrivers'

def scraper
  # set the chrome driver in specific path
  Selenium::WebDriver::Chrome::Service.driver_path=File.join(Dir.pwd, 'chromedriver.exe')
  browser = Watir::Browser.new
  
  url = 'https://www.vivareal.com.br/'
  browser.goto(url)
  
  form = browser.form(array: 'main-search__form js-base-search')
  return false unless form.exist?
  # seleciona o alugar
  form.select_list(class: 'js-select-business').option(value: 'rent').select
  # seleciona o tipo apartamento
  form.select_list(class: 'js-select-type').option(value: 'APARTMENT|UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX|RESIDENTIAL|APARTMENT').select
  # escreve catete na busca textual
  form.text_field.set('catete')
  # primeiro elemento, que é o bairro
  form.element(xpath: '//*[@id="js-site-main"]/section[1]/div/div/form[1]/div[2]/div/div/div/div/div/ul[1]/li').click
end

scraper