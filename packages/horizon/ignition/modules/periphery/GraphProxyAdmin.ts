import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

import GraphProxyAdminArtifact from '@graphprotocol/contracts/build/contracts/contracts/upgrades/GraphProxyAdmin.sol/GraphProxyAdmin.json'

export default buildModule('GraphProxyAdmin', (m) => {
  const governor = m.getParameter('governor')

  const GraphProxyAdmin = m.contract('GraphProxyAdmin', GraphProxyAdminArtifact)
  m.call(GraphProxyAdmin, 'transferOwnership', [governor])

  return { GraphProxyAdmin }
})
