instance_version = "4.0.1"
build_in_region = "us-west-1"
instance_sizes = { 
    xs = {
        instance_type = "m6a.2xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    s = {
        instance_type = "m6a.4xlarge"
        data_volume_type = "gp3"
        data_volume_size = 1000
    },
    m = {
        instance_type = "m6a.8xlarge"
        data_volume_type = "gp3"
        data_volume_size = 2000
    },
    l = {
        instance_type = "m6a.12xlarge"
        data_volume_type = "io2"
        data_volume_size = 5000
    },
    xl = {
        instance_type = "m6a.24xlarge"
        data_volume_type = "io2"
        data_volume_size = 5000
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
        "sa-east-1"
    ]