rm(list = ls())
library(TMB)
library(gulf.data)
library(gulf.graphics)

source("/Users/crustacean/Desktop/gulf-snow-crab-EAFM/R/TMB utilities.R")
source("/Users/crustacean/Desktop/gulf-snow-crab-EAFM/model/mixture by group/plot.instar.group.R")

years  <- 1988:2020  # Survey year.
sex    <- 2          # Crab sex.
maturity <- 0        # Crab maturity.

mu_instars <- c(10.5, 14.5, 20.5, 28.1, 37.8, 51.1, 68.0, 88.0)
names(mu_instars) <- 4:11
roman <- c("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV")
   
setwd("model/mixture by group")

# Work computer fix:
if (Sys.getenv("RSTUDIO_USER_IDENTITY") == "SuretteTJ") Sys.setenv(BINPREF = "C:/Rtools/mingw_64/bin/")

# Define data:
b <- read.scsbio(years, survey = "regular")
b <- b[which(b$sex == sex), ]
b <- b[which(b$carapace.width > 6), ]
if (length(maturity) > 0){
   if (maturity == 0) b <- b[which(!is.mature(b)), ] 
   if (maturity == 1) b <- b[which(is.mature(b)), ] 
}
if (sex == 2){
   b <- b[which(b$carapace.width <= 90), ] 
   if (maturity == 0) mu_instars <- mu_instars[as.character(4:10)]
   if (maturity == 1) mu_instars <- mu_instars[as.character(9:11)]
}else{
   b <- b[which(b$carapace.width <= 140), ]
} 
b$year <- year(b)
b$tow.id <- tow.id(b)
b <- b[!is.na(b$tow.id), ]
b <- sort(b, by = c("date", "tow.number", "crab.number"))

# Create tow table and tow index:
tows <- aggregate(list(n = b$carapace.width),  b[c("date", "tow.number", "tow.id")], length)
tows <- sort(tows, by = c("date", "tow.number"))
b$tow <- match(b[c("date", "tow.number")], tows[c("date", "tow.number")]) - 1
tows <- aggregate(list(n = b$carapace.width),  b[c("date", "tow", "tow.number", "tow.id")], length)
tows <- sort(tows, by = c("date", "tow.number"))

# Import swept area:
s <- read.scsset(years, valid = 1)
s <- s[!duplicated(s[c("date", "tow.number")]), ]
ix <- match(tows[c("date", "tow.number")], s[c("date", "tow.number")])
tows$swept.area <- s$swept.area[ix]

#ix <- which(is.mature(b) & !is.new.shell(b))
#b <- b[-ix, ]

#t <- table(b$tow)
#ix <- order(t)
#ix <- names(t)[rev(ix)[1:500]]
#b <- b[b$tow %in% as.numeric(ix), ]

if (maturity == 0) xlim = c(2.5, 4.25)
if (maturity == 1) xlim = c(3.5, 4.5)

c(3.22, 4.63, 6.62, 10.5, 14.5, 20.5, 28.1, 37.8, 51.1, 68.0, 88.0)
mu_instars <- c(10.5, 14.5, 20.5, 28.1, 37.8, 51.1, 68.0, 88.0)
names(mu_instars) <- 4:11
mu_instars <- mu_instars[as.character(4:9)]


# Set up data:
#r <- aggregate(list(f = b$year), list(x = round(log(b$carapace.width), 2), year = b$year), length)
r <- aggregate(list(f = b$year), 
               by = list(date = b$date,
                         tow.number = b$tow.number,
                         group = b$tow, 
                         year = b$year, 
                         x = round(log(b$carapace.width), 2)), 
               length)

data <- list(x = r$x, 
             f = r$f)
data$group <- r$group
data$year <- r$year
data$n_instar <- length(mu_instars)
data$n_group  <- max(data$group) + 1
data$precision <- rep(1, length(data$x))
data$precision[r$year >= 1998] <- 0.1
data$precision[r$year >= 1998] <- 0.1
data$tow.number <- r$tow.number
data$date <- r$date

# Define initial parameters:
parameters <- list(mu_instar_0 = as.numeric(log(mu_instars[1])),   # Mean size of the first instar.
                   log_increment = log(0.36),                         # Log-scale mean parameter associated with instar growth increments.
                   log_increment_delta = log(0.013),
                   log_sigma_mu_instar_group = -4,                 # Log-scale error for instar-group means random effect.
                   mu_instar_group = rep(0, length(mu_instars) * length(unique(data$group))),  # Instar-group means random effect.
                   log_sigma = -2,                                 # Log-scale instar standard error.
                   log_sigma_instar_group = rep(0, length(mu_instars) * length(unique(data$group))),
                   log_sigma_sigma_instar_group = -4,
                   mu_logit_p = 4,                                 # Instar proportions log-scale mean parameter.
                   log_sigma_logit_p_instar_group = -1,            # Instar-group proportions log-scale error parameter.
                   logit_p_instar_group = rep(0, (length(mu_instars)-1) * length(unique(data$group)))) # Multi-logit-scale parameters for instar-group proportions by year.
  
parameters <- parameters[parameters.cpp("instar_group_log.cpp")]

compile("instar_group_log.cpp")
dyn.load(dynlib("instar_group_log"))

random <- c("mu_instar_group", "logit_p_instar_group", "log_sigma_instar_group")

# Fit mixture proportions:
map <- lapply(parameters, function(x) as.factor(rep(NA, length(x))))
map$mu_logit_p <- factor(1)
map$log_sigma_logit_p_instar_group <- factor(1)
map$logit_p_instar_group <- factor(1:length(parameters$logit_p_instar_group))
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Fit mixture global standard errors:
map$log_sigma <- factor(1)
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

t <- table(data$group)
groups <- as.numeric(names(t[rev(order(t))]))[1:5]
plot.instar.group(obj, data, xlim = xlim, ylim = c(0, 20), groups = groups)

# Fit mixture global means:
map$log_increment <- factor(1)
map$log_increment_delta <- factor(1)
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Initial instar means:
map$mu_instar_0 <- factor(1)
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Fit mixture instar mean group random effect:
map$mu_instar_group <- factor(1:length(parameters$mu_instar_group))
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Fit mixture instar mean group random effect error parameter:
map$log_sigma_mu_instar_group <- factor(1)
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Fit mixture instar standard errors:
map$log_sigma_instar_group <- factor(1:length(parameters$log_sigma_instar_group))
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, map = map, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 1000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))

# Fit complete model:
obj <- MakeADFun(data[data.cpp("instar_group_log.cpp")], parameters, random = random, DLL = "instar_group_log")
theta <- optim(obj$par, obj$fn, control = list(trace = 3, maxit = 5000))$par
obj$par <- theta
rep <- sdreport(obj)
parameters <- update.parameters(parameters, summary(rep, "fixed"), summary(rep, "random"))
plot.instar.group(obj, data, xlim = xlim, groups = years)


mu_instar_group <- obj$report()$mu_instar_group
dim(mu_instar_group) <- c(length(years), length(mu_instars))
dimnames(mu_instar_group) <- list(year = years, instar = names(mu_instars))

# Instar proportions:
p <- obj$report()$p
dimnames(p) <- list(instar = names(mu_instars), year = years)
image(years, as.numeric(names(mu_instars)), t(p), ylab = "Instar")

# Instar standard errors:
sigma <- obj$report()$sigma
dimnames(sigma) <- list(instar = names(mu_instars), year = years)
image(years, as.numeric(names(mu_instars)), t(sigma), ylab = "Instar")


plot(apply(mu, 1, mean), apply(sigma, 1, mean))

sigma_instar_group <- obj$report()$sigma_instar_group
dim(sigma_instar_group) <- c(length(years), length(mu_instars))
dimnames(sigma_instar_group) <- list(year = years, instar = names(mu_instars))
image(years, as.numeric(names(mu_instars)), 
      log(sigma_instar_group), breaks = seq(-0.25, 0.25, len = 101), 
      col = colorRampPalette(c("red", "white", "blue"))(100), 
      ylab = "Year")


image(years, as.numeric(names(mu_instars)), 
      mu_instar_group, breaks = seq(-0.25, 0.25, len = 101), 
      col = colorRampPalette(c("red", "white", "blue"))(100), 
      ylab = "Year")

image(years, as.numeric(names(mu_instars)), 
      t(obj$report()$p), breaks = seq(0, 0.5, len = 101), 
      col = colorRampPalette(c("white", "red"))(100), 
      ylab = "Year")

# Export variables:
mu <- obj$report()$mu
dimnames(mu) <- list(names(mu_instars), years)

sigma <- obj$report()$sigma
dimnames(sigma) <- list(names(mu_instars), years)

# Calculate deltas for means 
clg()
plot(range(years), c(10, 75), type = "n", xlab = "Years", ylab = "Carapace width (mm)")
cols <- rainbow(nrow(mu))
grid()
for (i in 1:nrow(mu)){
   lines(years, exp(mu[i, ]), lwd = 2, col = cols[i])
   lines(years, exp(mu[i, ] - sigma[i, ]), lwd = 1, lty = "dashed", col = cols[i])
   lines(years, exp(mu[i, ] + sigma[i, ]), lwd = 1, lty = "dashed", col = cols[i])
}
text(rep(2005, nrow(mu)), exp(mu[, "2005"]), roman[as.numeric(rownames(mu))])

# Delta plot:
dmu <- exp(mu) - repvec(apply(exp(mu), 1, mean), ncol = ncol(mu))
clg()
colorbar(levels = seq(-3, 3, by = 1), color = colorRampPalette(c("red", "white", "blue"))(6),
         caption = c("difference(mm)"), smooth = TRUE)

image(years, as.numeric(names(mu_instars)), t(dmu), 
      breaks = seq(-3, 3, len = 101), 
      col = colorRampPalette(c("red", "white", "blue"))(100),
      xlab = "Years", ylab = "Instar")
box()





