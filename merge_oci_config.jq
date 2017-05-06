# Merges a sequence of OCI specs into one. Config values from later files take
# precedence. This generally uses naive recursive JSON merging logic as
# implemented by jq. Naive merging doesn't handle some areas of the OCI config
# objects incorrectly, so special handling is needed for them. Our strategy is
# to normalize the JSON data to a representation on which naive recursive
# merging produces the desired result, then de-normalize the merged result into
# JSON that is a valid OCI spec again.

# Denormalizes an OCI spec object into the mergeable representation. Performs
# the following transformations:
#  * The "mounts" array is replaced by a dictionary with the "destination"
#    value used as the key holding the mount entry.
# This isn't comprehensive, but just what is currently implemented. More
# transformations can be added as needed.
def normalize:
	.mounts |= reduce .[]? as $m ({}; . + {($m.destination): $m})
	;

# Inverts the transformations performed by normalize().
def denormalize:
	.mounts |= reduce .[]? as $m ([]; . + [$m])
	;

reduce .[] as $conf ({}; . * ($conf | normalize)) | denormalize
