const fs = require('fs');

const userData = fs.readFileSync(`${__dirname}/../files/user-data.sh`, 'utf-8');
const awscliConf = fs.readFileSync(`${__dirname}/../files/awscli.conf`, 'utf-8');
const awslogsConf = fs.readFileSync(`${__dirname}/../files/awslogs.conf`, 'utf-8');
const cfnHupConf = fs.readFileSync(`${__dirname}/../files/cfn-hup.conf`, 'utf-8');
const cfnAutoReloaderConf = fs.readFileSync(`${__dirname}/../files/cfn-auto-reloader.conf`, 'utf-8');

module.exports = {
  ECSCluster: {
    Type: 'AWS::ECS::Cluster',
    Properties: {
      ClusterName: {
        // eslint-disable-next-line no-template-curly-in-string
        'Fn::Sub': '${AWS::StackName}-Cluster',
      },
      Tags: [
        {
          Key: 'Name',
          Value: {
            // eslint-disable-next-line no-template-curly-in-string
            'Fn::Sub': '${AWS::StackName}-Cluster',
          },
        },
        {
          Key: 'Owner',
          Value: { Ref: 'ParamAuthorName' },
        },
      ],
    },
  },
  ECSAutoScalingGroup: {
    UpdatePolicy: {
      AutoScalingReplacingUpdate: {
        WillReplace: 'true',
      },
    },
    Type: 'AWS::AutoScaling::AutoScalingGroup',
    DependsOn: ['ECSCluster'],
    Properties: {
      VPCZoneIdentifier: {
        'Fn::Split': [
          ',',
          {
            'Fn::ImportValue': {
              // eslint-disable-next-line no-template-curly-in-string
              'Fn::Sub': '${ParamNetworkStackName}-PublicSubnets',
            },
          },
        ],
      },
      LaunchConfigurationName: {
        Ref: 'ContainerInstancesLC',
      },
      MinSize: {
        Ref: 'ParamECSMinSize',
      },
      MaxSize: {
        Ref: 'ParamECSMaxSize',
      },
      DesiredCapacity: {
        Ref: 'ParamECSDesiredCapacity',
      },
      Tags: [
        {
          Key: 'Name',
          Value: {
          // eslint-disable-next-line no-template-curly-in-string
            'Fn::Sub': '${AWS::StackName}-instance',
          },
          PropagateAtLaunch: 'True',
        },
        {
          Key: 'Owner',
          Value: { Ref: 'ParamAuthorName' },
          PropagateAtLaunch: 'True',
        },
      ],
    },
  },
  ContainerInstancesLC: {
    Type: 'AWS::AutoScaling::LaunchConfiguration',
    Metadata: {
      'AWS::CloudFormation::Init': {
        configSets: {
          default: ['tools', 'autoupdate'],
        },
        tools: {
          packages: {
            yum: {
              awslogs: [],
              jq: [],
            },
          },
          files: {
            '/etc/awslogs/awscli.conf': {
              content: {
                'Fn::Sub': awscliConf,
              },
              mode: '000644',
              owner: 'root',
              group: 'root',
            },
            '/etc/awslogs/awslogs.conf': {
              content: {
                'Fn::Sub': awslogsConf,
              },
              mode: '000644',
              owner: 'root',
              group: 'root',
            },
          },
          services: {
            sysvinit: {
              awslogsd: {
                enabled: true,
                ensureRunning: true,
                files: [
                  '/etc/awslogs/awscli.conf',
                  '/etc/awslogs/awslogs.conf',
                ],
                packages: {
                  yum: ['awslogs'],
                },
              },
            },
          },
        },
        autoupdate: {
          files: {
            '/etc/cfn/cfn-hup.conf': {
              content: {
                'Fn::Sub': cfnHupConf,
              },
              mode: '000400',
              owner: 'root',
              group: 'root',
            },
            '/etc/cfn/hooks.d/cfn-auto-reloader.conf': {
              content: {
                'Fn::Sub': cfnAutoReloaderConf,
              },
            },
          },
          services: {
            sysvinit: {
              'cfn-hup': {
                enabled: true,
                ensureRunning: true,
                files: [
                  '/etc/cfn/cfn-hup.conf',
                  '/etc/cfn/hooks.d/cfn-auto-reloader.conf',
                ],
              },
            },
          },
        },
      },
    },
    Properties: {
      ImageId: {
        'Fn::FindInMap': [
          'MapECSAMI',
          {
            Ref: 'AWS::Region',
          },
          'ID',
        ],
      },
      SecurityGroups: [
        { Ref: 'EcsHostSecurityGroup' },
        {
          'Fn::ImportValue': {
            // eslint-disable-next-line no-template-curly-in-string
            'Fn::Sub': '${ParamDBStackName}-DBAccessSecurityGroup',
          },
        },
      ],
      InstanceType: { Ref: 'ParamECSInstanceType' },
      KeyName: { Ref: 'ParamEcsInstancesKeyPair' },
      IamInstanceProfile: { Ref: 'EC2InstanceProfile' },
      AssociatePublicIpAddress: true,
      UserData: { 'Fn::Base64': { 'Fn::Sub': userData } },
    },
  },
};
