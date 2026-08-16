import numpy as np

class MSE():
    def __init__(self, y_test, y_pred):
            self.self = self
            self.y_test = y_test
            self.y_pred = y_pred

    def mean_squared_error(self, y_test, y_pred):
        #   if len(np.array([y_test])) == len(np.array([y_pred])) AND np.array([y_test]).notna().all() == True:
        if np.all(~np.isnan(y_test)) == np.all(~np.isnan(y_pred)):
             mse = ((y_test - y_pred) ** 2).mean()
             return mse