

* Directory
cd "C:\Users\saoud\Downloads\Thesis.Stata.Materials.04.09"

capture log close
cap ssc install reghdfe
cap ssc install ftools


*** Upload Raw Data


* Upload World stock index
import excel using "MSCI World Historical Data.xlsx", first clear sheet("MSCI World Historical Data)")
rename Date date
rename Price msci_price


keep date msci_price
sort date
save "msci_price", replace

* Upload Kuwait stock data
import excel using "data_original.xlsx", first clear sheet("Stocks")
rename Date date
drop I J

save "stocks", replace

* Upload oil data
import excel using "Oil_Price_Data.xls", first clear sheet("OilPrice")
drop D
drop if missing(date)
drop if date<mdy(5,21,1987)

save "oil", replace


* Upload days of week
import excel using  "Oil_Price_Data.xls", first clear sheet("days")
drop if missing(date)
gen year = year(date)
drop if date>mdy(4,6,2023)

save "dates", replace


* Merge stocks to oil prices
use "dates", clear
merge m:1 date using stocks, nogen
merge m:1 date using oil, nogen
merge m:1 date using "msci_price", nogen

order date dow year Event Price* oil*
save "data_full", replace



*** Create analytical variables
use "data_full", clear

* Replace oil variables with previous value if missing
replace oilwti = oilwti[_n-1] if missing(oilwti)
replace oilb = oilb[_n-1] if missing(oilb)
drop if missing(oilb)

* Replace world price variable with previous value if missing
replace msci_price = msci_price[_n-1] if missing(msci_price)
cap drop ch_msci_price

* Drop non-trading days
drop if missing(PriceKWD)

* Create percent changes
cap drop ch_KWD ch_oilwti ch_oilb ch_Vol
cap gen ch_KWD = PriceKWD[_n]/PriceKWD[_n-1]-1
cap gen ch_oilwti = oilwti[_n]/oilwti[_n-1]-1
cap gen ch_oilb = oilb[_n]/oilb[_n-1]-1
cap gen ch_Vol = VolMillionsKWD[_n]/VolMillionsKWD[_n-1]-1
cap gen ch_msci_price = msci_price[_n]/msci_price[_n-1]-1

save "data_new", replace

* Create event period
use data_new, clear
cap drop is_eventstart
gen is_eventstart = !missing(Event)
cap drop is_period
cap drop is_tenday
gen is_tenday = is_eventstart

order is*

forval i=1(1)10 {
	
	replace is_tenday = 1 if is_eventstart[_n-`i']==1
	
}
save data_new, replace


* Generate event periods


*** Analysis

* Regressions
use data_new, clear
xtset date

* Manually create dow indicators
forval i=1(1) 5 {
	
	cap gen is_day_`i' = dow == `i'
	
}

** Create world price index residuals from regressing on oil
reg ch_msci_price ch_oilb
predict msci_res, residuals

** T-Test of Returns
	tab is_tenday
	ttest ch_KWD, by(is_tenday)
	ttest ch_Vol, by(is_tenday)
	
** F-Test
	sdtest ch_KWD, by(is_tenday)
	sdtest ch_Vol, by(is_tenday)
	
** Medians
	bysort is_tenday: sum PriceKWD, de
	bysort is_tenday: sum ch_KWD, de
	bysort is_tenday: sum VolMillionsKWD, de
	bysort is_tenday: sum ch_Vol, de
	bysort is_tenday: sum oilb, de
	bysort is_tenday: sum ch_oilb, de
	bysort is_tenday: sum msci_price, de
	bysort is_tenday: sum ch_msci_price, de

** Baseline Effect on Stock Market
	* Baseline, Event on Stock Return
	reg ch_KWD is_tenday, vce(robust)
	
	* Median of Event on Stock Returns
	bysort is_tenday: sum ch_KWD, de
	
	* Oil Price on Stock Return
	reg ch_KWD ch_oilb, vce(robust)
	
	* Oil Price and World Return Residuals on Stock Return
	reg ch_KWD ch_oilb msci_res, vce(robust)
	
	* Event and Oil Price on Stock Return
	reg ch_KWD is_tenday ch_oilb, vce(robust)
	
	* Event and Oil Price on Stock Return with World Residuals
	reg ch_KWD is_tenday ch_oilb msci_res, vce(robust)
	
	* Event and Oil Price on Stock Return accounting for weekdays
	reg ch_KWD is_tenday ch_oilb is_day_1 is_day_2 is_day_3 is_day_4, vce(robust)
	
	* Event and Oil Price on Stock Return with World Residuals
	reg ch_KWD is_tenday ch_oilb msci_res is_day_1 is_day_2 is_day_3 is_day_4, vce(robust)
	
	
** Effects on Trading Volume
	* Baseline, Event on Volume Traded
	reg ch_Vol is_tenday, vce(robust)
	
	* Oil Price on Volume
	reg ch_Vol ch_oilb, vce(robust)
	
	* Oil Price and World Return Residuals on Volume
	reg ch_Vol ch_oilb msci_res, vce(robust)
	
	* Event and Oil Price on Volume
	reg ch_Vol is_tenday ch_oilb, vce(robust)
	
	* Event and Oil Price on Volume with World Residuals
	reg ch_Vol is_tenday ch_oilb msci_res, vce(robust)
	
	* Event and Oil Price on Volume accounting for weekdays
	reg ch_Vol is_tenday ch_oilb is_day_1 is_day_2 is_day_3 is_day_4, vce(robust)
	
	* Event and Oil Price on Volume with World Residuals accounting for weekdays
	reg ch_Vol is_tenday ch_oilb msci_res is_day_1 is_day_2 is_day_3 is_day_4, vce(robust)