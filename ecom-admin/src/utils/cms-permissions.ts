export const CMS_PERMISSIONS = {
  CATEGORY: {
    VIEW: 'cms:category:view',
    EDIT: 'cms:category:edit',
    DELETE: 'cms:category:delete',
  },
  TAG: {
    VIEW: 'cms:tag:view',
    EDIT: 'cms:tag:edit',
    DELETE: 'cms:tag:delete',
  },
  MODEL: {
    VIEW: 'cms:model:view',
    EDIT: 'cms:model:edit',
    DELETE: 'cms:model:delete',
  },
  CONTENT: {
    VIEW: 'cms:content:view',
    EDIT: 'cms:content:edit',
    DELETE: 'cms:content:delete',
    PUBLISH: 'cms:content:publish',
  },
  MEDIA: {
    VIEW: 'cms:media:view',
    UPLOAD: 'cms:media:upload',
    DELETE: 'cms:media:delete',
  },
  TEMPLATE: {
    VIEW: 'cms:template:view',
    EDIT: 'cms:template:edit',
    DELETE: 'cms:template:delete',
  },
  TRASH: {
    VIEW: 'cms:trash:view',
    RESTORE: 'cms:trash:restore',
    DELETE: 'cms:trash:delete',
  },
} as const;

export const CMS_MENU_PERMISSIONS = {
  MODEL: CMS_PERMISSIONS.MODEL.VIEW,
  CONTENT: CMS_PERMISSIONS.CONTENT.VIEW,
  CATEGORY: CMS_PERMISSIONS.CATEGORY.VIEW,
  TAG: CMS_PERMISSIONS.TAG.VIEW,
  MEDIA: CMS_PERMISSIONS.MEDIA.VIEW,
  TEMPLATE: CMS_PERMISSIONS.TEMPLATE.VIEW,
  TRASH: CMS_PERMISSIONS.TRASH.VIEW,
} as const;

export const CMS_ALL_PERMISSIONS = Object.values(CMS_PERMISSIONS).flatMap(
  (group) => Object.values(group)
);

export type CmsPermission = (typeof CMS_ALL_PERMISSIONS)[number];

export type CmsPermissionGroup = keyof typeof CMS_PERMISSIONS;

export function isCmsPermission(
  permission: string
): permission is CmsPermission {
  return CMS_ALL_PERMISSIONS.includes(permission as CmsPermission);
}

export function getCmsPermissionsByGroup(group: CmsPermissionGroup): string[] {
  return Object.values(CMS_PERMISSIONS[group]);
}

export function hasCmsPermission(
  userPermissions: string[],
  permission: CmsPermission
): boolean {
  return userPermissions.includes(permission);
}

export function hasAnyCmsPermission(
  userPermissions: string[],
  permissions: CmsPermission[]
): boolean {
  return permissions.some((permission) => userPermissions.includes(permission));
}

export function hasAllCmsPermissions(
  userPermissions: string[],
  permissions: CmsPermission[]
): boolean {
  return permissions.every((permission) =>
    userPermissions.includes(permission)
  );
}

export default CMS_PERMISSIONS;
