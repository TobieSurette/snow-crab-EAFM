library(TMB)
library(gulf.data)
library(gulf.spatial)
library(gulf.graphics)
library(gulf.stats)

# Model parameters:
n_instar <- 7
years  <- 2006:2020
sex <- 2
step <- 0.5

# Set derived quantities:
instars <- as.character(as.roman(4:(4+n_instar-1)))
n_year <- length(years)
if (sex == 1){
   n_instar <- 9
   xlim <- c(0, 140)
   ylim <- c(0, 40)
}else{
   n_instar <- 7
   xlim <- c(0, 100)
   ylim <- c(0, 40)   
}

# source("instar.year.data.R")
load("females.2006-2020.rdata")

# Work computer fix:
if (Sys.getenv("RSTUDIO_USER_IDENTITY") == "SuretteTJ") Sys.setenv(BINPREF = "C:/Rtools/mingw_64/bin/")

compile("instar_year.cpp")
dyn.load(dynlib("instar_year"))

# Define initial parameters:
parameters <- list(mu0                 = 10,                             # First instar mean size.
                   log_sigma0          = log(0.8),                       # Log-scale standard error for first instar.
                   log_hiatt_slope     = log(c(0.350, 0.055)),           # Hiatt slope parameters.
                   log_hiatt_intercept = log(c(0.689, 10.000)),          # Hiatt intercept parameters.
                   log_growth_error    = log(c(0.01, 0.25)),             # Growth increment error inflation parameters.
                   log_mu_year         = rep(0, n_instar * n_year),      # Log-scale instar mean year interaction (n_instar x n_year).
                   log_sigma_mu_year   = -3,                             # Instar mean year interaction error term.
                   delta_mat = -1.5, 
                   log_n_imm_year_0    = rep(4, n_instar-1),             # First year immature instar abundances (n_instar-1).
                   log_n_imm_instar_0  = rep(4, n_year),                 # First instar recruitment for all years (n_year).
                   log_sigma_n_imm_instar_0 = -1,                        # Log-scale first instar annual recruitment error parameter.
                   log_n_skp_instar_0  = rep(0, n_instar-5),             # First year skip abundances (n_instar-5).                         
                   log_n_rec_instar_0  = rep(0, n_instar-5),             # First year mature recruit abundances (n_instar-5).
                   log_n_res_instar_0  = rep(0, n_instar-5),             # First year mature residual abundances (n_instar-5).
                   selectivity_x50     = 25,                             # Size-at-50% trawl selectivity.
                   log_selectivity_slope = -1,                           # Log-scale trawl selectivity slope.
                   log_year_effect = rep(0, n_year),                     # Abundance year effect (n_year).
                   log_sigma_year_effect = -2,                           # Log-scale year effect error parameter.
                   logit_p_skp = c(rep(-8, 4), rep(-6, n_instar-5)),     # Logit-scale skip-moulting probabilities (n_instar).
                   logit_p_mat = c(rep(-8, 4), rep(0, n_instar-6), 3),   # Logit-scale moult-to-maturity probabilities (n_instar).
                   logit_p_mat_year = rep(0, (n_instar-1) * (n_year-1)), # Logit-scale mout-to-maturity instar x year interaction (n_instar x n_year).
                   log_sigma_p_mat_year = -1,                            # Moult-to-maturity instar x year interaction error term.
                   logit_M_imm = -1,                                     # Logit-scale immature mortality.
                   logit_M_mat = c(-1.10, -1.73))                        # Logit-scale mature mortality.  


load("female.parameters.2006-2020.rdata")
parameters <- parameters[-grep("selectivity", names(parameters))]
parameters$selectivity_x50 = 25 # Size-at-50% trawl selectivity.
parameters$log_selectivity_slope = -1 
#parameters$log_year_effect <- rep(0, length(parameters$log_year_effect))

# Define random variables in model:
random <- c("log_mu_year", "log_n_imm_instar_0", "logit_p_mat_year", "log_year_effect")
data.vars <- names(data)[-grep("(rec)|(res)|(skp)", names(data))]
   
# Initialize parameter mapping:
map <- lapply(parameters, function(x) factor(rep(NA, length(x))))

# Estimate initial abundance parameters:
map <- update.map(map, free = c("log_n_imm_instar_0", "log_n_imm_year_0", "log_n_skp_instar_0", "log_n_rec_instar_0", "log_n_res_instar_0", "log_sigma_n_imm_instar_0"))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add selectivity parameters:
map <- update.map(map, free = c("selectivity_x50", "log_selectivity_slope"))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add mortality parameters:
map <- update.map(map, free = c("logit_M_mat","logit_M_imm"))
#map$logit_M_mat <- factor(rep(1, 2))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add moult to maturity parameters:
map <- update.map(map, free = c("logit_p_mat", "logit_p_mat_year", "log_sigma_p_mat_year"))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 300))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add year effect parameters:
map <- update.map(map, free = c("log_sigma_year_effect"))
parameters$log_year_effect[length(parameters$log_year_effect)] <- 0
map$log_year_effect <- factor(c(1:(length(parameters$log_year_effect)-1 ), NA))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 300))$par
parameters <- update.parameters(parameters, obj, map = map)


parameters$logit_M_mat <- c(-1.10, -1.73)

# Add instar error parameter:
map <- update.map(map, free = c("log_growth_error")) 
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 200))$par
parameters <- update.parameters(parameters, obj, map = map)

#parameters$log_hiatt_slope <- c(-1.049822, -2.385967)
#parameters$log_hiatt_intercept <- c( -0.372514,  2.302585)
#parameters$log_selectivity_slope <- c(-1.100514, -1)

# Add some growth parameters:
map <- update.map(map, free = c("log_hiatt_slope", "log_hiatt_intercept", "log_sigma0"))
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 500))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add annual growth parameters:
parameters$log_mu_year[which(abs(parameters$log_mu_year) > 0.15)] <- 0
map <- update.map(map, free = c("log_mu_year", "log_sigma_mu_year")) 
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 500))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add mature delta parameter:
map <- update.map(map, free = "delta_mat") 
parameters$delta_mat <- -3
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
parameters <- update.parameters(parameters, obj, map = map)

# Add first instar parameters:
map <- update.map(map, free = "mu0") 
obj <- MakeADFun(data[data.vars], parameters, DLL = "instar_year",  random = random, map = map)
obj$par <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 500))$par
parameters <- update.parameters(parameters, obj, map = map)

save(parameters, file = "female.parameters.2006-2020.rdata")





