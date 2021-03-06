library(mlr)
rm(list = ls())
OS = "Windows"
set.seed(1)

# Load the environment
load(file = "../Data_BenchmarkOpenMl/Final/DataMining/clas_time.RData")
clas_used = rbind(clas_time_small, clas_time_medium)
OMLDATASETS = clas_used$did[c(1:140)]
source(file = "benchmark_defs.R")


## Example 1 - Multi-core on a single computer
sink('SnowFallExample.Rout', split=TRUE)
.Platform
.Machine
R.version
Sys.info()

library(snowfall) 
# 1. Initialisation of snowfall. 
# (if used with sfCluster, just call sfInit()) 
sfInit(parallel=TRUE, cpus=10)

# 2. Loading data. 

# 3. Wrapper, which can be parallelised. 
runBenchmark <- function(data.index) {
  
  library(OpenML)
  library(mlr)
  
  print(paste("debut dataset ", data.index))
  print(Sys.time())
  # get the dataset
  omldataset = getOMLDataSet(data.index)
  if (identical(omldataset$target.features, character(0))) {
    omldataset$target.features="Class"
    omldataset$desc$default.target.attribute="Class"
  }
  task = convertOMLDataSetToMlr(omldataset)
  task$task.desc$id = paste("dataset", data.index)
  
  
  # learners
  lrn.classif.lr = makeLearner("classif.logreg", predict.type = "prob", fix.factors.prediction = TRUE) #2class
  lrn.classif.rf = makeLearner("classif.randomForest", predict.type = "prob", fix.factors.prediction = TRUE) #multiclass
  
  # regularized
  lrn.classif.lrlasso = makeLearner("classif.penalized.lasso", predict.type = "prob", fix.factors.prediction = TRUE, standardize=TRUE) #two class #no factor
  lrn.classif.lrridge = makeLearner("classif.penalized.ridge", predict.type = "prob", fix.factors.prediction = TRUE) #two class #no factor
  lrn.classif.lrfusedlasso = makeLearner("classif.penalized.fusedlasso", predict.type = "prob", fix.factors.prediction = TRUE)#two class 
  
  # nnet
  lrn.classif.multinom = makeLearner("classif.multinom", predict.type = "prob", fix.factors.prediction = TRUE)
  
  # also use glmnet
  lrn.classif.lr.glm.ridge = makeLearner("classif.cvglmnet", predict.type = "prob", fix.factors.prediction = TRUE, alpha = 0)
  lrn.classif.lr.glm.ridge$id = "classif.cvglmnet.ridge"
  lrn.classif.lr.glm.lasso = makeLearner("classif.cvglmnet", predict.type = "prob", fix.factors.prediction = TRUE, alpha = 1)
  lrn.classif.lr.glm.lasso$id = "classif.cvglmnet.lasso"
  lrn.classif.lr.glm.lasso.min = makeLearner("classif.cvglmnet", predict.type = "prob", fix.factors.prediction = TRUE, alpha = 1,  s = "lambda.min")
  lrn.classif.lr.glm.lasso.min$id = "classif.cvglmnet.lasso.min"
  lrn.classif.lr.glm.vanilla = makeLearner("classif.glmnet", predict.type = "prob", fix.factors.prediction = TRUE, alpha = 1,  s = 0)
  lrn.classif.lr.glm.vanilla$id = "classif.cvglmnet.lasso.vanilla"
  
  # list of learners
  lrn.list = list(lrn.classif.lr, #stats package
                  lrn.classif.rf, #randomForest package
                  lrn.classif.lrlasso, #lrn.classif.lrridge, #regularized package
                  #lrn.classif.multinom, #nnet package
                  #lrn.classif.lr.glm.ridge
                  lrn.classif.lr.glm.lasso, #glmnet package
                  lrn.classif.lr.glm.lasso.min,
                  lrn.classif.lr.glm.vanilla)
  
  # measures
  measures = MEASURES
  rdesc = makeResampleDesc("RepCV", folds = 5, reps = 10, stratify = TRUE)
  configureMlr(on.learner.error = "warn", show.learner.output = FALSE)
  bmr = benchmark(lrn.list, task, rdesc, measures, keep.pred = FALSE, models = FALSE, show.info = FALSE)
  print(paste("fin dataset ", data.index))
  return(bmr)
}

wrapper <- function(data.index) {
tryCatch({
  
  # benchmark
  runBenchmark(data.index)
}, error = function(e) return(paste0("The variable '", data.index, "'", 
                                     " caused the error: '", e, "'")))
}


# 4. Exporting needed data and loading required 
# packages on workers. 
sfExport("MEASURES", "runBenchmark") 
sfLibrary(cmprsk) 

# 5. Start network random number generator 
# (as "sample" is using random numbers). 
sfClusterSetupRNG() 

# 6. Distribute calculation
start <- Sys.time(); result <- sfLapply(OMLDATASETS, wrapper) ; Sys.time()-start


# 7. Stop snowfall 
sfStop() 

save(result, clas_used, file = "../Data_BenchmarkOpenMl/Final/Results/Windows/benchmark_120_rf-lr-lasso-lasso.min-lassopenalized-glmvanilla.RData")
print("done with cluster")
