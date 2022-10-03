instance_version = "4.0.1"
build_in_region = "us-west-2"
instance_sizes = { 
    xs = {
        instance_type = "m6a.2xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    s = {
        instance_type = "m6a.4xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    m = {
        instance_type = "m6a.8xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    l = {
        instance_type = "m6a.12xlarge"
        data_volume_type = "io2"
        data_volume_size = 500
    },
    xl = {
        instance_type = "m6a.24xlarge"
        data_volume_type = "io2"
        data_volume_size = 500
    }
}
ami_regions = [
        "us-west-1",
        "us-west-2",
        "us-east-1",
        "us-east-2",
        "eu-west-1",
        "eu-central-1",
        "ap-northeast-1",
        "ap-northeast-2",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-south-1",
        "sa-east-1",
        "eu-west-2", 
        "eu-west-3",
        "eu-south-1",
        "eu-north-1",
        "ca-central-1",
        "me-south-1",
        "me-central-1",
        "ap-east-1",
        "af-south-1",
        "ap-southeast-3",
    ]