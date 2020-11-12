#include <TMB.hpp>
template<class Type> Type objective_function<Type>::operator()(){
   // Data:
   DATA_VECTOR(x);

   // Parameters:
   PARAMETER(log_mu_0);
   PARAMETER(log_sigma);
   PARAMETER(log_mu_inc);
   PARAMETER(log_sigma_inc);
   PARAMETER_VECTOR(log_inc);
   PARAMETER_VECTOR(log_p);
   
   // Vector sizes:      
   int n = x.size();
   int k = log_inc.size() + 1;
   
   // Initialize log-likelihood:
   Type v = 0;
   
   // Random effect for increments:
   Type mu_inc = exp(log_mu_inc);
   Type sigma_inc = exp(log_sigma_inc);
   v += -sum(dnorm(log_inc, mu_inc, sigma_inc, true));
   
   // Mixture component proportions:
   vector<Type> p(k);
   p[0] = 1 / (1 + sum(exp(log_p)));
   for (int j = 1; j < k; j++){
      p[j] = exp(log_p[j-1]) / (1 + sum(exp(log_p)));
   }

   // Mixture component means:
   vector<Type> mu(k);
   mu[0] = exp(log_mu_0);
   for (int j = 1; j < k; j++){
      mu[j] = mu[j-1] + exp(log_inc[j-1]);
   }
   
   // Mixture likelihood:
   vector<Type> d(n);
   d.fill(0);
   Type sigma = exp(log_sigma);
   for (int j = 0; j < k; j++){
      d += p[j] * dnorm(x, mu[j], sigma, false); 
   }
   v += -sum(log(p));
   
   // Export parameters:
   REPORT(p);
   REPORT(mu);
   REPORT(sigma);
   
   return v;
}
