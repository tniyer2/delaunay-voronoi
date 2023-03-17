class_name Util extends Object


"""
Sorts an array efficiently in ascending order.
Precomputes comparison values so they are calculated in
O(n) time rather than in sort time (at least O(nlogn)).
arr: the array to sort.
order_func: a function which maps an element to a comparison value.
"""
static func sort_array(arr, order_func):
	var comparison_values = arr.map(order_func)
	
	var sorted_indices = range(len(arr)) # initially [0...n-1]
	sorted_indices.sort_custom(func(a, b):
		return comparison_values[a] < comparison_values[b])
	
	return sorted_indices.map(func(i): return arr[i])
