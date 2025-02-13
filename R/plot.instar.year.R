plot.instar <- function(obj, data, xlim = c(10, 140)){
   clg()
   dev.new(width = 8.5, height = 11)
   m <- s <- p <- NULL

   gbarplot(data$f, data$x, border = "grey50", width = 0.01, xlim = xlim, xaxs = "i", xaxt = "n", yaxt = "n", lwd = 0.5)
   grid()
   x0 <- seq(0, 5, len = 1000)
   d <- rep(0, length(x0))
   for (j in 1:data$n_instar){
      lines(x0, 0.01 * obj$report()$p[j] * sum(data$f) * dnorm(x0, obj$report()$mu[j], obj$report()$sigma[j]), lwd = 0.5, lty = "dashed", col = "blue")
      d  <- d + 0.01 * obj$report()$p[j] * sum(data$f) * dnorm(x0, obj$report()$mu[j], obj$report()$sigma[j]) 
   }
   lines(x0, d, col = "blue", lwd = 0.5)
      
   vline(obj$report()$mu, col = "blue", lwd = 0.5)
   mtext("Frequency", 2, 2.5, cex = 1.25, at = 0)
   mtext("Carapace width(mm)", 1, 2.5, cex = 1.25)
   box()
}

plot.instar.year <- function(obj, data, xlim = c(2.0, 5), ylim = c(0, 200)){
   clg()
   dev.new(width = 8.5, height = 11)
   m <- kronecker(matrix(1:33, ncol = 3), matrix(1, ncol = 3, nrow = 3))
   m <- rbind(0, cbind(0, 0, m, 0), 0, 0)
   layout(m)
   par(mar = c(0,0,0,0))
   m <- s <- p <- NULL
   for (i in 1:length(years)){   
      # Plot output:
      gbarplot(data$f[data$year == i-1], data$x[data$year == i-1], 
               border = "grey50", width = 0.01, xlim = xlim, 
               xaxs = "i", xaxt = "n", yaxt = "n", ylim = ylim, lwd = 0.5)
      grid()
      x0 <- seq(0, 5, len = 1000)
      d <- rep(0, length(x0))
      for (j in 1:length(obj$report()$mu_instar)){
         lines(x0, 0.01 * obj$report()$p[j,i] * sum(data$f[data$year == i-1]) * dnorm(x0, obj$report()$mu[j,i], obj$report()$sigma_instar[j]), lwd = 0.5, lty = "dashed", col = "blue")
         d <- d + .01 * obj$report()$p[j,i] * sum(data$f[data$year == i-1]) * dnorm(x0, obj$report()$mu[j,i], obj$report()$sigma_instar[j]) 
      }
      lines(x0, d, col = "blue", lwd = 0.5)
   
      vline(obj$report()$mu[,i], 
            col = "blue", 
            lwd = 0.5)
      
      if (i <= 8) axis(2)
      if (i == 8) axis(1, at = seq(2, xlim[2]-0.5, by = 0.5))
      if (i == 16) axis(1, at = seq(2, xlim[2], by = 0.5))
      if (i == length(years)) axis(1, at = seq(2.5, xlim[2], by = 0.5))
      if (i == length(years)/2) mtext("log(cw)", 1, 2.5, at = par("usr")[2])
      if (i == 4) mtext("Frequency", 2, 2.5, cex = 1.25, at = 0)
      if (i == 16) mtext("ln(cw)", 1, 2.5, cex = 1.25)
      
      # Year label:
      text(par("usr")[1] + 0.1 * diff(par("usr")[1:2]), par("usr")[3] + 0.85 * diff(par("usr")[3:4]), years[i], cex = 0.8)
      
      box()
   }
}


